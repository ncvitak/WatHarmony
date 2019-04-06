//
//  Chunker.swift
//  WatHarmonyKit
//
//  Created by Nicholas Cvitak on 2019-03-12.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

import Accelerate

public class Chunker {
	public let length: Int
	private var head: Int
	private var rbuffer: UnsafeMutablePointer<Float>
	private var wbuffer: UnsafeMutablePointer<Float>
	private var isProcessing: Bool
	
	public init(length: Int) {
		self.length = max(0, length)
		self.head = 0
		self.rbuffer = UnsafeMutablePointer<Float>.allocate(capacity: length)
		self.wbuffer = UnsafeMutablePointer<Float>.allocate(capacity: length)
		self.isProcessing = false
		
		var zero: Float = 0.0
		vDSP_vfill(&zero, self.rbuffer, 1, vDSP_Length(length))
	}
	
	deinit {
		self.rbuffer.deallocate()
		self.wbuffer.deallocate()
	}
	
	public func process(buffer: UnsafeMutablePointer<Float>, length: Int, _ block: (UnsafeMutablePointer<Float>) -> Void) {
		guard !isProcessing else {
			Console.log(.error, "cannot call recursively!")
			return
		}
		
		isProcessing = true
		defer {
			isProcessing = false
		}
		
		var i = 0
		while i < length {
			let n = min(self.length - head, length - i)
			memcpy(wbuffer.advanced(by: head), buffer.advanced(by: i), n * MemoryLayout<Float>.stride)
			memcpy(buffer.advanced(by: i), rbuffer.advanced(by: head), n * MemoryLayout<Float>.stride)
			head += n
			if head == self.length {
				block(wbuffer)
				swap(&rbuffer, &wbuffer)
				head = 0
			}
			i += n
		}
	}
}
