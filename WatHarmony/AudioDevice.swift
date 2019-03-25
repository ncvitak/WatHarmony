//
//  AudioDevice.swift
//  WatHarmony
//
//  Created by Nicholas Cvitak on 2019-03-10.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

import Foundation
import CoreAudio
import CoreFoundation
import WatHarmonyKit

struct AudioDevice {
	var deviceID: AudioDeviceID
	
	init(deviceID: AudioDeviceID) {
		self.deviceID = deviceID
	}
}

// MARK: - Devices

extension AudioDevice {
	static func devices() throws -> [AudioDevice] {
		var err = noErr
		var error: Error
		var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
		
		var size: UInt32 = 0
		err = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
		guard err == noErr else {
			error = NSError(domain: NSOSStatusErrorDomain, code: Int(err))
			Console.log(.error, "failed to get number of devices! \(error)")
			throw error
		}
		
		let deviceCount = Int(size) / MemoryLayout<AudioDeviceID>.stride
		var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
		
		err = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices)
		guard err == noErr else {
			error = NSError(domain: NSOSStatusErrorDomain, code: Int(err))
			Console.log(.error, "failed to get devices! \(error)")
			throw error
		}
		
		return devices.map(AudioDevice.init(deviceID:))
	}
	
	static func inputDevices() throws -> [AudioDevice] {
		do {
			return try AudioDevice.devices().filter({ try $0.isInput() })
		} catch {
			Console.log(.error, "failed to get input devices! \(error)")
			throw error
		}
	}
	
	static func outputDevices() throws -> [AudioDevice] {
		do {
			return try AudioDevice.devices().filter({ try $0.isOutput() })
		} catch {
			Console.log(.error, "failed to get output devices! \(error)")
			throw error
		}
	}
	
	static func defaultInput() throws -> AudioDevice {
		var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
		var size = UInt32(MemoryLayout<AudioDeviceID>.size)
		var deviceID: AudioDeviceID = 0
		
		let err = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
		guard err == noErr else {
			let error = NSError(domain: NSOSStatusErrorDomain, code: Int(err))
			Console.log(.error, "failed to get default input device \(deviceID)! \(error)")
			throw error
		}
		
		return AudioDevice(deviceID: deviceID)
	}
	
	func makeDefaultInput() throws {
		var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
		var deviceID = self.deviceID
		
		let err = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &deviceID)
		guard err == noErr else {
			let error = NSError(domain: NSOSStatusErrorDomain, code: Int(err))
			Console.log(.error, "failed to set default input device \(deviceID)! \(error)")
			throw error
		}
	}
	
	static func defaultOutput() throws -> AudioDevice {
		var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
		var size = UInt32(MemoryLayout<AudioDeviceID>.size)
		var deviceID: AudioDeviceID = 0
		
		let err = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
		guard err == noErr else {
			let error = NSError(domain: NSOSStatusErrorDomain, code: Int(err))
			Console.log(.error, "failed to get default output device \(deviceID)! \(error)")
			throw error
		}
		
		return AudioDevice(deviceID: deviceID)
	}
	
	func makeDefaultOutput() throws {
		var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
		var deviceID = self.deviceID
		
		let err = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &deviceID)
		guard err == noErr else {
			let error = NSError(domain: NSOSStatusErrorDomain, code: Int(err))
			Console.log(.error, "failed to set default output device \(deviceID)! \(error)")
			throw error
		}
	}
}

// MARK: - Properties

extension AudioDevice {
	func uid() throws -> String {
		var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
		var size = UInt32(MemoryLayout<UnsafeMutableRawPointer>.size)
		var string: CFString!
		
		let err = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &string)
		guard err == noErr else {
			let error = NSError(domain: NSOSStatusErrorDomain, code: Int(err))
			Console.log(.error, "failed to get uid for device \(deviceID)! \(error)")
			throw error
		}
		
		return string as String
	}
	
	func name() throws -> String {
		var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceNameCFString, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
		var size = UInt32(MemoryLayout<UnsafeMutableRawPointer>.size)
		var string: CFString!
		
		let err = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &string)
		guard err == noErr else {
			let error = NSError(domain: NSOSStatusErrorDomain, code: Int(err))
			Console.log(.error, "failed get name for device \(deviceID)! \(error)")
			throw error
		}
		
		return string as String
	}
	
	func isInput() throws -> Bool {
		var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioObjectPropertyScopeInput, mElement: kAudioObjectPropertyElementMaster)
		
		var size: UInt32 = 0
		let err = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
		guard err == noErr else {
			let error = NSError(domain: NSOSStatusErrorDomain, code: Int(err))
			Console.log(.error, "failed to get inputs for device \(deviceID)! \(error)")
			throw error
		}
		
		return size > 0
	}
	
	func isOutput() throws -> Bool {
		var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMaster)
		
		var size: UInt32 = 0
		let err = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
		guard err == noErr else {
			let error = NSError(domain: NSOSStatusErrorDomain, code: Int(err))
			Console.log(.error, "failed to get outputs for device \(deviceID)! \(error)")
			throw error
		}
		
		return size > 0
	}
}

// MARK: - CustomStringConvertible

extension AudioDevice: CustomStringConvertible {
	var description: String {
		return (try? name()) ?? "Device \(deviceID)"
	}
}

// MARK: - CustomDebugStringConvertible

extension AudioDevice: CustomDebugStringConvertible {
	var debugDescription: String {
		return "\(deviceID):\(self)"
	}
}
