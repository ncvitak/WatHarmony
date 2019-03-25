//
//  Scale.swift
//  WatHarmonyKit
//
//  Created by Nicholas Cvitak on 2019-03-09.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

public struct Scale: Equatable {
	public let intervals: [Interval]
	let index: [Int?]
	
	public init?(intervals: [Interval]) {
		guard intervals.map({ $0.rawValue }).reduce(0, +) == Pitch.Class.count else {
			return nil
		}
		
		var index = [Int?].init(repeating: nil, count: Pitch.Class.count)
		var i = 0, j = 0
		for interval in intervals {
			index[i] = j
			i += interval.rawValue
			j += 1
		}
		
		self.intervals = intervals
		self.index = index
	}
	
	public static func==(lhs: Scale, rhs: Scale) -> Bool {
		return lhs.intervals == rhs.intervals
	}
	
	public static let major = Scale(intervals: [.tone, .tone, .semitone, .tone, .tone, .tone, .semitone])!
	public static let minor = Scale(intervals: [.tone, .semitone, .tone, .tone, .semitone, .tone, .tone])!
}
