//
//  PitchScaler.swift
//  WatHarmonyKit
//
//  Created by Nicholas Cvitak on 2019-03-13.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

import Accelerate

public protocol PitchScalerDelegate: AnyObject {
	func scale(buffer: UnsafePointer<Float>) -> Float
}

public class PitchScaler {
	public let log2Length: Int
	public let length: Int
	public let sampleRate: Float
	public let overlap: Int
	
	public weak var delegate: PitchScalerDelegate?
	public var mix: Float = 0.5 {
		didSet {
			mix = max(0, min(mix, 1))
		}
	}
	
	private let analysisHop: Int
	private var synthesisHop: Int
	private let chunker: Chunker
	
	private let analysisBuffer: UnsafeMutablePointer<Float>
	private let synthesisBuffer: UnsafeMutablePointer<Float>
	private let normalizeBuffer: UnsafeMutablePointer<Float>
	
	private let fft: FFTSetup
	private var complex: DSPSplitComplex
	
	private var initalized: Bool = false
	
	private let magnitude: UnsafeMutablePointer<Float>
	private let phase: UnsafeMutablePointer<Float>
	
	private let lastAnalysisPhase: UnsafeMutablePointer<Float>
	private let lastSynthesisPhase: UnsafeMutablePointer<Float>
	
	private let tbuffer: UnsafeMutablePointer<Float>
	
	private let centerFrequency: UnsafePointer<Float>
	private let window: UnsafePointer<Float>
	private let normalizeWindow: UnsafePointer<Float>
	
	private let vTwoPiF: UnsafePointer<Float>
	
	init(log2Length: Int, sampleRate: Float, overlap: Int = 4) {
		assert(log2Length >= 0)
		assert((1 << log2Length) % overlap == 0)
		
		self.log2Length = log2Length
		self.length = 1 << log2Length
		self.sampleRate = sampleRate
		self.overlap = overlap
		
		self.analysisHop = length / overlap
		self.synthesisHop = analysisHop
		
		self.chunker = Chunker(length: analysisHop)
		
		self.fft = vDSP_create_fftsetup(vDSP_Length(log2Length), FFTRadix(kFFTRadix2))!
		self.complex = DSPSplitComplex(realp: .allocate(capacity: length), imagp: .allocate(capacity: length))
		
		self.magnitude = .allocate(capacity: length)
		self.phase = .allocate(capacity: length)
		
		self.analysisBuffer = .allocate(capacity: length)
		self.synthesisBuffer = .allocate(capacity: length)
		self.normalizeBuffer = .allocate(capacity: length)
		
		var zero = Float(0)
		vDSP_vfill(&zero, analysisBuffer, 1, vDSP_Length(length))
		vDSP_vfill(&zero, synthesisBuffer, 1, vDSP_Length(length))
		vDSP_vfill(&zero, normalizeBuffer, 1, vDSP_Length(length))
		
		self.lastAnalysisPhase = .allocate(capacity: length)
		self.lastSynthesisPhase = .allocate(capacity: length)
		
		self.tbuffer = .allocate(capacity: length)
		
		do {
			let centerFrequency = UnsafeMutablePointer<Float>.allocate(capacity: length)
			
			var a0 = Float(0), b0 = Float(length/2 - 1)
			vDSP_vgen(&a0, &b0, centerFrequency, 1, vDSP_Length(length/2))
			
			var a1 = Float(-length/2), b1 = Float(-1)
			vDSP_vgen(&a1, &b1, centerFrequency.advanced(by: length/2), 1, vDSP_Length(length/2))
			
			var c = (2 * .pi) / Float(length)
			vDSP_vsmul(centerFrequency, 1, &c, centerFrequency, 1, vDSP_Length(length))
			
			self.centerFrequency = UnsafePointer(centerFrequency)
		}
		
		do {
			let window = UnsafeMutablePointer<Float>.allocate(capacity: length)
			let normalizeWindow = UnsafeMutablePointer<Float>.allocate(capacity: length)
			var scale = 2 / Float(overlap)
			
			vDSP_hann_window(window, vDSP_Length(length), Int32(vDSP_HANN_DENORM))
			vDSP_vsmul(window, 1, &scale, window, 1, vDSP_Length(length))
			
			vDSP_vmul(window, 1, window, 1, normalizeWindow, 1, vDSP_Length(length))
			
			self.window = UnsafePointer(window)
			self.normalizeWindow = UnsafePointer(normalizeWindow)
		}
		
		do {
			let vTwoPiF = UnsafeMutablePointer<Float>.allocate(capacity: length)
			var twoPi = 2 * Float.pi
			
			vDSP_vfill(&twoPi, vTwoPiF, 1, vDSP_Length(length))
			
			self.vTwoPiF = UnsafePointer(vTwoPiF)
		}
	}
	
	deinit {
		vDSP_destroy_fftsetup(fft)
		complex.realp.deallocate()
		complex.imagp.deallocate()
		
		magnitude.deallocate()
		phase.deallocate()
		
		analysisBuffer.deallocate()
		synthesisBuffer.deallocate()
		normalizeBuffer.deallocate()
		
		lastAnalysisPhase.deallocate()
		lastSynthesisPhase.deallocate()
		
		tbuffer.deallocate()
		
		centerFrequency.deallocate()
		
		window.deallocate()
		normalizeWindow.deallocate()
		
		vTwoPiF.deallocate()
	}
	
	private func unwrap(phase: UnsafeMutablePointer<Float>) {
		var piF = Float.pi
		vDSP_vsadd(phase, 1, &piF, phase, 1, vDSP_Length(length))
		
		var lengthI = Int32(length)
		vvfmodf(phase, phase, vTwoPiF, &lengthI)
		vDSP_vadd(phase, 1, vTwoPiF, 1, phase, 1, vDSP_Length(length))
		vvfmodf(phase, phase, vTwoPiF, &lengthI)
		
		piF = -piF
		vDSP_vsadd(phase, 1, &piF, phase, 1, vDSP_Length(length))
	}
	
	private func process(chunk: UnsafeMutablePointer<Float>) {
		let epsilon = sqrtf(.ulpOfOne)
		var zeroF = Float(0)
		var lengthI = Int32(length)
		var lengthF = Float(length)
		var synthesisEndF = Float(synthesisHop - 1)
		
		// push the chunk into analysis buffer
		memmove(analysisBuffer, analysisBuffer.advanced(by: analysisHop), (length - analysisHop) * MemoryLayout<Float>.stride)
		memcpy(analysisBuffer.advanced(by: length - analysisHop), chunk, analysisHop * MemoryLayout<Float>.stride)
		
		// normalize portion of synthesis buffer to be read
		for i in 0..<synthesisHop {
			if normalizeBuffer[i] < epsilon {
				normalizeBuffer[i] = 1.0
			}
		}
		vDSP_vdiv(normalizeBuffer, 1, synthesisBuffer, 1, synthesisBuffer, 1, vDSP_Length(synthesisHop))
		
		// resample from synthesis buffer
		vDSP_vgen(&zeroF, &synthesisEndF, tbuffer, 1, vDSP_Length(analysisHop))
		vDSP_vlint(synthesisBuffer, tbuffer, 1, tbuffer, 1, vDSP_Length(analysisHop), vDSP_Length(synthesisHop))
		
		// mix into chunk for ouput
		do {
			var analysisScaleF = 2.0 - 2.0 * max(0.5, mix)
			var synthesisScaleF = 2.0 * min(mix, 0.5)
			
			vDSP_vsmul(chunk, 1, &analysisScaleF, chunk, 1, vDSP_Length(analysisHop))
			vDSP_vsmul(tbuffer, 1, &synthesisScaleF, tbuffer, 1, vDSP_Length(analysisHop))
			vDSP_vadd(chunk, 1, tbuffer, 1, chunk, 1, vDSP_Length(analysisHop))
		}
		
		// push zeros into the synthesis buffer
		memmove(synthesisBuffer, synthesisBuffer.advanced(by: synthesisHop), (length - synthesisHop) * MemoryLayout<Float>.stride)
		vDSP_vfill(&zeroF, synthesisBuffer.advanced(by: length - synthesisHop), 1, vDSP_Length(synthesisHop))
		
		// push zeros into the normalize buffer
		memmove(normalizeBuffer, normalizeBuffer.advanced(by: synthesisHop), (length - synthesisHop) * MemoryLayout<Float>.stride)
		vDSP_vfill(&zeroF, normalizeBuffer.advanced(by: length - synthesisHop), 1, vDSP_Length(synthesisHop))
		
		// update pitch shift
		if let scale = delegate?.scale(buffer: analysisBuffer) {
			self.synthesisHop = Int(roundf(scale * Float(analysisHop)))
		} else {
			self.synthesisHop = analysisHop
		}
		
		// copy windowed analysis frame into complex buffer
		vDSP_vmul(analysisBuffer, 1, window, 1, complex.realp, 1, vDSP_Length(length))
		vDSP_vfill(&zeroF, complex.imagp, 1, vDSP_Length(length))
		
		// perform in-place fft
		vDSP_fft_zip(fft, &complex, 1, vDSP_Length(log2Length), FFTDirection(kFFTDirection_Forward))
		
		// extract magnitude and phase
		vDSP_zvabs(&complex, 1, magnitude, 1, vDSP_Length(length))
		vDSP_zvphas(&complex, 1, phase, 1, vDSP_Length(length))
		
		if !initalized {
			memcpy(lastSynthesisPhase, phase, length * MemoryLayout<Float>.stride)
			initalized = true
		} else {
			var analysisHopF = Float(analysisHop)
			var synthesisHopF = Float(synthesisHop)
			
			// compute phase increment
			vDSP_vsmul(centerFrequency, 1, &analysisHopF, tbuffer, 1, vDSP_Length(length))
			vDSP_vadd(tbuffer, 1, lastAnalysisPhase, 1, tbuffer, 1, vDSP_Length(length))
			vDSP_vsub(tbuffer, 1, phase, 1, tbuffer, 1, vDSP_Length(length))
			
			// unwrap phase increment
			unwrap(phase: tbuffer)
			
			// compute instantaneous
			vDSP_vsdiv(tbuffer, 1, &analysisHopF, tbuffer, 1, vDSP_Length(length))
			vDSP_vadd(tbuffer, 1, centerFrequency, 1, tbuffer, 1, vDSP_Length(length))
			vDSP_vsmul(tbuffer, 1, &synthesisHopF, tbuffer, 1, vDSP_Length(length))

			// accumulate
			vDSP_vadd(lastSynthesisPhase, 1, tbuffer, 1, lastSynthesisPhase, 1, vDSP_Length(length))
			unwrap(phase: lastSynthesisPhase)
			
			// recontruct from phase and magnitude
			vvcosf(complex.realp, lastSynthesisPhase, &lengthI)
			vvsinf(complex.imagp, lastSynthesisPhase, &lengthI)
			vDSP_zrvmul(&complex, 1, magnitude, 1, &complex, 1, vDSP_Length(length))
		}
		
		// perform in-place ifft
		vDSP_fft_zip(fft, &complex, 1, vDSP_Length(log2Length), FFTDirection(kFFTDirection_Inverse))
		
		// take real part and fix scale
		vDSP_vsdiv(complex.realp, 1, &lengthF, tbuffer, 1, vDSP_Length(length))
		
		// apply window
		vDSP_vmul(tbuffer, 1, window, 1, tbuffer, 1, vDSP_Length(length))
		
		// add into synthesis buffer
		vDSP_vadd(synthesisBuffer, 1, tbuffer, 1, synthesisBuffer, 1, vDSP_Length(length))
		
		// add normalize window into normalize buffer
		vDSP_vadd(normalizeBuffer, 1, normalizeWindow, 1, normalizeBuffer, 1, vDSP_Length(length))
		
		// update last analysis phase
		memcpy(lastAnalysisPhase, phase, length * MemoryLayout<Float>.stride)
	}
	
	func process(buffer: UnsafeMutablePointer<Float>, length: Int) {
		chunker.process(buffer: buffer, length: length, process(chunk:))
	}
}
