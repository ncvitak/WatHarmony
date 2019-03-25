//
//  AudioEngine.swift
//  WatHarmony
//
//  Created by Nicholas Cvitak on 2019-03-10.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

import AVFoundation
import CoreAudio
import WatHarmonyKit

class AudioEngine {
	private var engine: AVAudioEngine?
	private var audioUnit: AVAudioUnit?
	private(set) var input: AudioDevice
	private(set) var output: AudioDevice
	
	init(input: AudioDevice, output: AudioDevice, audioUnit: AVAudioUnit? = nil) throws {
		try input.makeDefaultInput()
		try output.makeDefaultOutput()
		
		self.engine = try AudioEngine.createAVAudioEngine(audioUnit: audioUnit)
		self.audioUnit = audioUnit
		self.input = input
		self.output = output
	}
	
	var isRunning: Bool {
		return engine?.isRunning ?? false
	}
	
	func start() throws {
		guard engine != nil, !engine!.isRunning else {
			return
		}
		try engine!.start()
		Console.log(.default, "<%p> started", unsafeBitCast(self, to: Int.self))
	}
	
	func stop() {
		guard engine != nil, engine!.isRunning else {
			return
		}
		engine!.stop()
		Console.log(.default, "<%p> stopped", unsafeBitCast(self, to: Int.self))
	}
	
	func set(input: AudioDevice) throws {
		try set(input: input, output: output)
	}
	
	func set(output: AudioDevice) throws {
		try set(input: input, output: output)
	}
	
	static func createAVAudioEngine(audioUnit: AVAudioUnit? = nil) throws -> AVAudioEngine {
		let engine = AVAudioEngine()
		
		let format = AVAudioFormat(standardFormatWithSampleRate: engine.inputNode.outputFormat(forBus: 0).sampleRate, channels: 1)
		if let audioUnit = audioUnit {
			engine.attach(audioUnit)
			engine.connect(engine.inputNode, to: audioUnit, format: format)
			engine.connect(audioUnit, to: engine.mainMixerNode, format: format)
		} else {
			engine.connect(engine.inputNode, to: engine.mainMixerNode, format: format)
		}
		return engine
	}
	
	func set(input: AudioDevice, output: AudioDevice) throws {
		let wasRunning = engine?.isRunning ?? false
		
		if wasRunning {
			engine!.stop()
		}
		
		if let audioUnit = audioUnit {
			engine?.detach(audioUnit)
		}
		
		engine = nil
		
		try input.makeDefaultInput()
		try output.makeDefaultOutput()
		
		engine = try AudioEngine.createAVAudioEngine(audioUnit: audioUnit)
		
		if wasRunning {
			try engine!.start()
		}
		
		self.input = input
		self.output = output
	}
}
