//
//  ViewController.swift
//  WatHarmony
//
//  Created by Nicholas Cvitak on 2019-03-03.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

import AudioToolbox
import Cocoa
import WatHarmonyKit
import Foundation
import AVFoundation

class ViewController: NSViewController {
	@IBOutlet var inputButton: NSPopUpButton!
	@IBOutlet var outputButton: NSPopUpButton!
	@IBOutlet var ioButton: NSButton!
	
	var engine: AudioEngine!
	var harmonizerAudioUnit: HarmonizerAudioUnit!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let desc = AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: HarmonizerAudioUnit.subType, componentManufacturer: HarmonizerAudioUnit.manufacturer, componentFlags: AudioComponentFlags.sandboxSafe.rawValue, componentFlagsMask: 0)
		AUAudioUnit.registerSubclass(HarmonizerAudioUnit.self, as: desc, name: HarmonizerAudioUnit.name, version: UInt32.max)
		
		do {
			let defaultInput = try AudioDevice.defaultInput()
			let inputDevices = try AudioDevice.inputDevices()
			for device in inputDevices {
				let item = NSMenuItem(title: device.description, action: #selector(selectInput(item:)), keyEquivalent: "")
				item.target = self
				item.tag = Int(device.deviceID)
				inputButton.menu!.addItem(item)
				
				if device.deviceID == defaultInput.deviceID {
					inputButton.select(item)
				}
			}
			
			let defaultOutput = try AudioDevice.defaultOutput()
			let outputDevices = try AudioDevice.outputDevices()
			for device in outputDevices {
				let item = NSMenuItem(title: device.description, action: #selector(selectOutput(item:)), keyEquivalent: "")
				item.target = self
				item.tag = Int(device.deviceID)
				
				outputButton.menu!.addItem(item)
				
				if device.deviceID == defaultOutput.deviceID {
					outputButton.select(item)
				}
			}
			
			let input = AudioDevice(deviceID: AudioDeviceID(inputButton.selectedTag()))
			let output = AudioDevice(deviceID: AudioDeviceID(outputButton.selectedTag()))
			let effect = AVAudioUnitEffect(audioComponentDescription: desc)
			harmonizerAudioUnit = (effect.auAudioUnit as! HarmonizerAudioUnit)
			
			engine = try AudioEngine(input: input, output: output, audioUnit: effect)
			
		} catch {
			Console.log(.fault, "failed to setup ViewController")
			NSAlert(error: error).runModal()
			NSApp.terminate(self)
		}
	}
	
	override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
		super.prepare(for: segue, sender: segue)
		
		if let harmonizerAudioUnitViewController = segue.destinationController as? HarmonizerAudioUnitViewController {
			harmonizerAudioUnitViewController.audioUnit = harmonizerAudioUnit
		}
	}
	
	private func startIO() {
		if #available(macOS 10.14, *) {
			switch AVCaptureDevice.authorizationStatus(for: .audio) {
			case .notDetermined:
				AVCaptureDevice.requestAccess(for: .audio) { _ in
					DispatchQueue.main.async(execute: self.startIO)
				}
				return
			case .denied:
				NSAlert(error: NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES), userInfo: nil)).runModal()
				return
			default:
				break
			}
		}
		
		do {
			try engine.start()
			ioButton.title = "Stop IO"
		} catch {
			NSAlert(error: error).runModal()
		}
	}
	
	private func stopIO() {
		engine.stop()
		ioButton.title = "Start IO"
	}

	@objc func selectInput(item: NSMenuItem) {
		do {
			try engine.set(input: AudioDevice(deviceID: AudioDeviceID(item.tag)))
		} catch {
			NSAlert(error: error).runModal()
		}
	}
	
	@objc func selectOutput(item: NSMenuItem) {
		do {
			try engine.set(output: AudioDevice(deviceID: AudioDeviceID(item.tag)))
		} catch {
			NSAlert(error: error).runModal()
		}
	}
	
	@IBAction func ioButtonAction(button: NSButton) {
		if !engine.isRunning {
			startIO()
		} else {
			stopIO()
		}
	}
}

