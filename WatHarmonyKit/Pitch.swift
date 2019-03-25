//
//  Pitch.swift
//  WatHarmonyKit
//
//  Created by Nicholas Cvitak on 2019-03-09.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

import Foundation

public struct Pitch {
	var value: Int
	
	init(value: Int) {
		self.value = value
	}
}

// MARK: - Arithmetic

public extension Pitch {
	public static func +(lhs: Pitch, rhs: Int) -> Pitch {
		return Pitch(value: lhs.value + rhs)
	}
	
	public static func +=(lhs: inout Pitch, rhs: Int) {
		lhs.value += rhs
	}
	
	public static func -(lhs: Pitch, rhs: Int) -> Pitch {
		return Pitch(value: lhs.value - rhs)
	}
	
	public static func -=(lhs: inout Pitch, rhs: Int) {
		lhs.value -= rhs
	}
	
	public static func -(lhs: Pitch, rhs: Pitch) -> Int {
		return lhs.value - rhs.value
	}
	
	public static func /(lhs: Pitch, rhs: Pitch) -> Float {
		return pow(2, Float(lhs - rhs) / 12)
	}
}

public extension Pitch {
	public static func +(lhs: Pitch, rhs: Interval) -> Pitch {
		return lhs + rhs.rawValue
	}
	
	public static func +=(lhs: inout Pitch, rhs: Interval) {
		lhs += rhs.rawValue
	}
	
	public static func -(lhs: Pitch, rhs: Interval) -> Pitch {
		return lhs - rhs.rawValue
	}
	
	public static func -=(lhs: inout Pitch, rhs: Interval) {
		lhs -= rhs.rawValue
	}
}

// MARK: - Class & Octave

public extension Pitch {
	public enum Class: Int {
		case C
		case Db
		case D
		case Eb
		case E
		case F
		case Gb
		case G
		case Ab
		case A
		case Bb
		case B
		
		static let count = 12
	}
	
	public init(class: Class, octave: Int) {
		self.value = 12 * octave + `class`.rawValue
	}
	
	public var `class`: Class {
		return Class(rawValue: value.mod(12))!
	}
	
	public var octave: Int {
		return value / 12
	}
}

// MARK: - Frequency

public extension Pitch {
	public init?(frequency: Float) {
		guard frequency > 0 else {
			return nil
		}
		
		self.value = Int(round(12 * log2(frequency / 27.5) + 9))
	}
	
	public var frequency: Float {
		return 27.5 * pow(2, Float(value - 9) / 12)
	}
}

// MARK: - CustomStringConvertible

extension Pitch: CustomStringConvertible {
	public var description: String {
		return "\(self.class)\(self.octave)"
	}
}
