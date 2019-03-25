//
//  Key.swift
//  WatHarmonyKit
//
//  Created by Nicholas Cvitak on 2019-03-09.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

public struct Key {
	public var root: Pitch.Class
	public var scale: Scale
	
	public init(root: Pitch.Class, scale: Scale) {
		self.root = root
		self.scale = scale
	}
	
	public func contains(pitch: Pitch.Class) -> Bool {
		return scale.index[(pitch.rawValue - root.rawValue).mod(Pitch.Class.count)] != nil
	}
	
	public func contains(pitch: Pitch) -> Bool {
		return contains(pitch: pitch.class)
	}
	
	public func transpose(pitch: Pitch, degree: Int) -> Pitch? {
		guard var index = scale.index[(pitch.class.rawValue - root.rawValue).mod(Pitch.Class.count)] else {
			return nil
		}
		
		let tindex = index + degree
		var transposed = pitch
		
		if degree > 0 {
			while index < tindex {
				transposed += scale.intervals[index.mod(scale.intervals.count)]
				index += 1
			}
		} else {
			while index > tindex {
				index -= 1
				transposed -= scale.intervals[index.mod(scale.intervals.count)]
			}
		}
		
		return transposed
	}
}
