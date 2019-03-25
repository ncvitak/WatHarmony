//
//  PitchTransposer.swift
//  WatHarmonyKit
//
//  Created by Nicholas Cvitak on 2019-03-20.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

public class PitchTransposer: PitchScalerDelegate {
	public var key: Key
	public var degree: Int
	public let log2Length: Int
	public let length: Int
	public let sampleRate: Float
	private let detector: PitchDetector
	
	internal private(set) var lastTranspose: (Pitch.Class, Pitch.Class) = (.C, .C)
	
	public init(key: Key, degree: Int, log2Length: Int, sampleRate: Float) {
		self.key = key
		self.degree = degree
		self.log2Length = log2Length
		self.length = 1 << log2Length
		self.sampleRate = sampleRate
		
		self.detector = PitchDetector(log2Length: log2Length, sampleRate: sampleRate)
	}
	
	public func scale(buffer: UnsafePointer<Float>) -> Float {
		guard let base = detector.pitch(buffer: buffer) else {
			return 1.0
		}
		guard let harmony = key.transpose(pitch: base, degree: degree) else {
			lastTranspose = (base.class, base.class)
			return 1.0
		}
		Console.log(.debug, "\(base) -> \(harmony)")
		lastTranspose = (base.class, harmony.class)
		return harmony / base
	}
}
