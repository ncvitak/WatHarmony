//
//  HarmonizerAudioUnit.swift
//  WatHarmonyKit
//
//  Created by Nicholas Cvitak on 2019-03-04.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

import AudioToolbox
import AVFoundation

public class HarmonizerAudioUnit: AUAudioUnit {
	public static let subType: FourCharCode = 0x686D7A72 // hmzr
	public static let manufacturer: FourCharCode = 0x57617448 // WatH
	public static let name: String = "WatHarmony: Harmonizer"
	
	public enum ParameterAddress: AUParameterAddress {
		case root = 0x686D7A72_00000001
		case scale = 0x686D7A72_00000002
		case degree = 0x686D7A72_00000003
		case mix = 0x686D7A72_00000004
	}
	
	private static let _noteUnitValues = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	private static let _scaleUnitValues = ["Major", "Minor"]
	
	private var _inputBus: AUAudioUnitBus
	private var _outputBus: AUAudioUnitBus
	
	private var _inputBusses: AUAudioUnitBusArray!
	private var _outputBusses: AUAudioUnitBusArray!
	
	private let _parameterTree: AUParameterTree
	
	private var _pitchTransposer: PitchTransposer?
	private var _pitchScalers: [PitchScaler] = []
	
	private var _root: Pitch.Class = .C {
		didSet {
			_pitchTransposer?.key.root = _root
		}
	}
	private var _scale: Scale = .major {
		didSet {
			_pitchTransposer?.key.scale = _scale
		}
	}
	private var _degree: Int = 0 {
		didSet {
			_pitchTransposer?.degree = _degree
		}
	}
	private var _mix: Float = 0.5 {
		didSet {
			_mix = max(0, min(_mix, 1))
			for pitchScaler in _pitchScalers {
				pitchScaler.mix = _mix
			}
		}
	}
	
	private var _lastRenderTime: CFAbsoluteTime = 0
	internal func lastTranspose() -> (Pitch.Class, Pitch.Class)? {
		guard CFAbsoluteTimeGetCurrent() - _lastRenderTime <= (Double(2*maximumFramesToRender) / _inputBus.format.sampleRate) else {
			return nil
		}
		return _pitchTransposer?.lastTranspose
	}
	
	public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
		// setup parameter tree
		let rootParameter = AUParameterTree.createParameter(
			withIdentifier: "root", name: "Root", address: ParameterAddress.root.rawValue,
			min: 0, max: 11, unit: .indexed, unitName: "PitchClass",
			flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: HarmonizerAudioUnit._noteUnitValues, dependentParameters: nil
		)
		let scaleParameter = AUParameterTree.createParameter(
			withIdentifier: "scale", name: "Scale", address: ParameterAddress.scale.rawValue,
			min: 0, max: 1, unit: .indexed, unitName: "Scale",
			flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: HarmonizerAudioUnit._scaleUnitValues, dependentParameters: nil
		)
		let degreeParameter = AUParameterTree.createParameter(
			withIdentifier: "degree", name: "Degree", address: ParameterAddress.degree.rawValue,
			min: -7, max: 7, unit: .degrees, unitName: nil,
			flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil
		)
		let mixParameter = AUParameterTree.createParameter(
			withIdentifier: "mix", name: "Mix", address: ParameterAddress.mix.rawValue,
			min: 0, max: 100, unit: .percent, unitName: nil,
			flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
		mixParameter.value = 50
		
		_parameterTree = AUParameterTree.createTree(withChildren: [rootParameter, scaleParameter, degreeParameter, mixParameter])
		
		// setup input/output busses
		let format = AVAudioFormat(standardFormatWithSampleRate: 48000.0, channels: 1)!
		
		_inputBus = try AUAudioUnitBus(format: format)
		_outputBus = try AUAudioUnitBus(format: format)
		
		try super.init(componentDescription: componentDescription, options: options)
		
		_inputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [_inputBus])
		_outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [_outputBus])
		
		// connect parameter tree implementors
		_parameterTree.implementorValueObserver = { [unowned self] in
			self._implementorValueObserver(parameter: $0, value: $1)
		}
		_parameterTree.implementorValueProvider = { [unowned self] in
			return self._implementorValueProvider(parameter: $0)
		}
	}
	
	// MARK: AUAudioUnit Overrides
	
	public override var inputBusses: AUAudioUnitBusArray {
		return _inputBusses
	}
	
	public override var outputBusses: AUAudioUnitBusArray {
		return _outputBusses
	}
	
	public override var parameterTree: AUParameterTree? {
		return _parameterTree
	}
	
	public override var latency: TimeInterval {
		guard let pitchScaler = _pitchScalers.first else {
			return 0
		}
		return Double(pitchScaler.length + (pitchScaler.length / pitchScaler.overlap)) / _inputBus.format.sampleRate
	}
	
	public override func allocateRenderResources() throws {
		Console.log(.default, "")
		try super.allocateRenderResources()
		
		guard _inputBus.format == _outputBus.format else {
			Console.log(.error, "input format does not equal output format! (input: \(_inputBus.format), output: \(_outputBus.format))")
			self.setRenderResourcesAllocated(false)
			throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
		}
		guard _inputBus.format.isStandard else {
			Console.log(.error, "only standard (deinterleaved native-endian float) format supported! (format: \(_inputBus.format))")
			self.setRenderResourcesAllocated(false)
			throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
		}
		
		let sampleRate = Float(_inputBus.format.sampleRate)
		let samplesRequired = 2 * (sampleRate / Pitch(class: .C, octave: 2).frequency)
		let log2Length = Int(ceil(log2(samplesRequired)))
		
		let pitchTransposer = PitchTransposer(key: Key(root: _root, scale: _scale), degree: _degree, log2Length: log2Length, sampleRate: sampleRate)
		let pitchScalers = (0..<_inputBus.format.channelCount).map { _ -> PitchScaler in
			let pitchScaler = PitchScaler(log2Length: log2Length, sampleRate: sampleRate, overlap: 8)
			
			pitchScaler.delegate = pitchTransposer
			pitchScaler.mix = _mix
			
			return pitchScaler
		}
		
		_pitchTransposer = pitchTransposer
		_pitchScalers = pitchScalers
	}
	
	public override func deallocateRenderResources() {
		Console.log(.default, "")
		super.deallocateRenderResources()
		
		_pitchScalers = []
		_pitchTransposer = nil
	}
	
	// MARK: - AUAudioUnit (AUAudioUnitImplementation)
	
	public override var internalRenderBlock: AUInternalRenderBlock {
		return { [unowned self] actionFlags, timestamp, frameCount, outputBusNumber, outputData, realtimeEventListHead, pullInputBlock in
			return self._render(
				actionFlags: actionFlags,
				timestamp: timestamp,
				frameCount: frameCount,
				outputBusNumber: outputBusNumber,
				outputData: outputData,
				realtimeEventListHead: realtimeEventListHead,
				pullInputBlock: pullInputBlock
			)
		}
	}
	
	private func _render(
		actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
		timestamp: UnsafePointer<AudioTimeStamp>,
		frameCount: AUAudioFrameCount,
		outputBusNumber: Int,
		outputData: UnsafeMutablePointer<AudioBufferList>,
		realtimeEventListHead: UnsafePointer<AURenderEvent>?,
		pullInputBlock: AURenderPullInputBlock?
	) -> AUAudioUnitStatus {
		var err: AUAudioUnitStatus = noErr
		
		guard let pullInputBlock = pullInputBlock else {
			Console.log(.error, "pullInputBlock is nil!")
			return kAudioUnitErr_NoConnection
		}
		
		var flags: AudioUnitRenderActionFlags = []
		err = pullInputBlock(&flags, timestamp, frameCount, 0, outputData)
		guard err == noErr else {
			Console.log(.error, "pullInput failed! \(NSError(domain: NSOSStatusErrorDomain, code: Int(err)))")
			return err
		}
		
		let output = UnsafeMutableAudioBufferListPointer(outputData)
		for i in 0..<output.count {
			let buffer = output[i].mData!.assumingMemoryBound(to: Float.self)
			_pitchScalers[i].process(buffer: buffer, length: Int(frameCount))
		}
		
		_lastRenderTime = CFAbsoluteTimeGetCurrent()
		return err
	}
	
	private func _implementorValueObserver(parameter: AUParameter, value: AUValue) {
		guard let address = ParameterAddress(rawValue: parameter.address) else {
			return
		}
		
		switch address {
		case .root:
			_root = Pitch.Class(rawValue: Int(value).mod(Pitch.Class.count))!
		case .scale:
			_scale = Int(value) % 2 == 0 ? .major : .minor
		case .degree:
			_degree = max(-7, min(Int(value), +7))
		case .mix:
			_mix = 0.01 * max(0, min(value, 100))
		}
	}
	
	private func _implementorValueProvider(parameter: AUParameter) -> AUValue {
		guard let address = ParameterAddress(rawValue: parameter.address) else {
			return .nan
		}
		
		switch address {
		case .root:
			return AUValue(_root.rawValue)
		case .scale:
			switch _scale {
			case Scale.major:
				return 0
			case Scale.minor:
				return 1
			default:
				return .nan
			}
		case .degree:
			return AUValue(_degree)
		case .mix:
			return 100 * _mix
		}
	}
}
