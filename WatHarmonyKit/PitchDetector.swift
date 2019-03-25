//
//  PitchDetector.swift
//  WatHarmonyKit
//
//  Created by Nicholas Cvitak on 2019-03-09.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

import Accelerate

public class PitchDetector {
	public let log2Length: Int
	public let length: Int
	public let sampleRate: Float
	
	private let fft: FFTSetup
	private var complex: DSPSplitComplex
	
	public init(log2Length: Int, sampleRate: Float) {
		assert(log2Length >= 0)
		assert(sampleRate > 0)
		
		self.log2Length = log2Length
		self.length = 1 << log2Length
		self.sampleRate = sampleRate
		
		self.fft = vDSP_create_fftsetup(vDSP_Length(log2Length + 1), FFTRadix(kFFTRadix2))!
		self.complex = DSPSplitComplex(realp: .allocate(capacity: 2 * length), imagp: .allocate(capacity: 2 * length))
	}
	
	deinit {
		vDSP_destroy_fftsetup(fft)
		complex.realp.deallocate()
		complex.imagp.deallocate()
	}
	
	public func frequency(buffer: UnsafePointer<Float>) -> Float {
		var zeroF = Float(0)
		var length2F = Float(2 * length)
		
		// clear complex
		vDSP_vfill(&zeroF, complex.realp, 1, vDSP_Length(2 * length))
		vDSP_vfill(&zeroF, complex.imagp, 1, vDSP_Length(2 * length))
		
		// re-center signal at zero
		var mean: Float = 0.0
		vDSP_meanv(buffer, 1, &mean, vDSP_Length(length))
		
		mean = -mean
		vDSP_vsadd(buffer, 1, &mean, complex.realp, 1, vDSP_Length(length))
		
		// perform autocorrelation using fft
		vDSP_fft_zip(fft, &complex, 1, vDSP_Length(log2Length + 1), FFTDirection(kFFTDirection_Forward))
		
		vDSP_zvmul(&complex, 1, &complex, 1, &complex, 1, vDSP_Length(2 * length), -1)
		
		vDSP_fft_zip(fft, &complex, 1, vDSP_Length(log2Length + 1), FFTDirection(kFFTDirection_Inverse))
		vDSP_vsdiv(complex.realp, 1, &length2F, complex.imagp, 1, vDSP_Length(2 * length))
		
		memcpy(complex.realp, complex.imagp.advanced(by: length), length * MemoryLayout<Float>.stride)
		memcpy(complex.realp.advanced(by: length), complex.imagp, length * MemoryLayout<Float>.stride)
		
		// find highest peak
		var m: (Float, vDSP_Length) = (0, 0)
		vDSP_maxvi(complex.realp, 1, &m.0, &m.1, vDSP_Length(2 * length))
		
		// erase peak
		var l = Int(m.1)
		while l > 0 && complex.realp[l-1] <= complex.realp[l] {
			l -= 1
		}
		
		var r = Int(m.1)
		while r < (2 * length - 1) && complex.realp[r+1] <= complex.realp[r] {
			r += 1
		}
		
		for i in l...r {
			complex.realp[i] = 0.0
		}
		
		// find next highest peak
		var k: (Float, vDSP_Length) = (0, 0)
		vDSP_maxvi(complex.realp, 1, &k.0, &k.1, vDSP_Length(2 * length))
		
		// calculate and return pitch
		return sampleRate / Float(abs(Int(k.1) - Int(m.1) + 1))
	}
	
	public func pitch(buffer: UnsafePointer<Float>) -> Pitch? {
		return Pitch(frequency: self.frequency(buffer: buffer))
	}
}
