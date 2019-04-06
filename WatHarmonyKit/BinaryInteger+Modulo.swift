//
//  BinaryInteger+Modulo.swift
//  WatHarmonyKit
//
//  Created by Nicholas Cvitak on 2019-03-09.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

infix operator %+: MultiplicationPrecedence
infix operator %+=: AssignmentPrecedence

extension BinaryInteger {
	func mod(_ m: Self) -> Self {
		return ((self % m) + m) % m
	}
	
	static func %+(lhs: Self, rhs: Self) -> Self {
		return lhs.mod(rhs)
	}
	
	static func %+=(lhs: inout Self, rhs: Self) {
		lhs = lhs.mod(rhs)
	}
}
