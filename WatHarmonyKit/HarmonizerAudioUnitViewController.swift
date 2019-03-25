//
//  HarmonizerAudioUnitViewController.swift
//  WatHarmonyKit
//
//  Created by Nicholas Cvitak on 2019-03-04.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

import CoreAudioKit

public class HarmonizerAudioUnitViewController: AUViewController {
	@IBOutlet var baseLabel: NSTextField?
	@IBOutlet var harmonyLabel: NSTextField?
	@IBOutlet var rootPopUpButton: NSPopUpButton?
	@IBOutlet var scaleSegmentedControl: NSSegmentedControl?
	@IBOutlet var degreePopUpButton: NSPopUpButton?
	@IBOutlet var mixSlider: NSSlider?
	
	private var allParameterValuesObserver: NSKeyValueObservation?
	private var parameterObserverToken: AUParameterObserverToken?
	
	private static let pitchClassNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	
	public var audioUnit: HarmonizerAudioUnit? {
		willSet {
			audioUnit?.parameterTree?.removeParameterObserver(parameterObserverToken!)
			allParameterValuesObserver?.invalidate()
			allParameterValuesObserver = nil
		}
		didSet {
			parameterObserverToken = audioUnit?.parameterTree?.token(byAddingParameterObserver: { [unowned self] in
				self.parameterObserver(address: $0, value: $1)
			})
			allParameterValuesObserver = audioUnit?.observe(\HarmonizerAudioUnit.allParameterValues) { [unowned self] _, _  in
				DispatchQueue.main.async(execute: self.updateAllParameters)
			}
		}
	}
	
	private var isTimerResumed: Bool = false
	private lazy var timer: DispatchSourceTimer = {
		let timer = DispatchSource.makeTimerSource(flags: [], queue: .main)
		timer.setEventHandler(handler: { [unowned self] in
			guard let audioUnit = self.audioUnit, let transpose = audioUnit.lastTranspose() else {
				self.baseLabel?.stringValue = ""
				self.harmonyLabel?.stringValue = ""
				return
			}
			
			self.baseLabel?.stringValue = HarmonizerAudioUnitViewController.pitchClassNames[transpose.0.rawValue]
			self.harmonyLabel?.stringValue = HarmonizerAudioUnitViewController.pitchClassNames[transpose.1.rawValue]
		})
		timer.schedule(deadline: .now(), repeating: .milliseconds(100))
		return timer
	}()
	
	public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil ?? "HarmonizerAudioUnitViewController", bundle: nibBundleOrNil ?? Bundle(for: HarmonizerAudioUnitViewController.self))
	}
	
	public required init?(coder: NSCoder) {
		super.init(nibName: "HarmonizerAudioUnitViewController", bundle: Bundle(for: HarmonizerAudioUnitViewController.self))
	}
	
	deinit {
		if isTimerResumed {
			timer.cancel()
		}
	}
	
	public override func viewDidLoad() {
		super.viewDidLoad()
		
		for label in [baseLabel!, harmonyLabel!] {
			label.layer!.backgroundColor = NSColor.darkGray.cgColor
			label.layer!.cornerRadius = 4
		}
		updateAllParameters()
	}
	
	public override func viewWillAppear() {
		super.viewWillAppear()
		
		if !isTimerResumed {
			timer.resume()
			isTimerResumed = true
		}
	}
	
	public override func viewDidDisappear() {
		super.viewDidDisappear()
		
		if isTimerResumed {
			timer.suspend()
			isTimerResumed = false
		}
	}
	
	private func updateAllParameters() {
		guard let audioUnit = audioUnit else {
			return
		}
		
		rootPopUpButton!.selectItem(at: min(Int(
			audioUnit.parameterTree!.parameter(withAddress: HarmonizerAudioUnit.ParameterAddress.root.rawValue)!.value
		), rootPopUpButton!.itemArray.count - 1))
		
		scaleSegmentedControl!.selectedSegment = min(Int(
			audioUnit.parameterTree!.parameter(withAddress: HarmonizerAudioUnit.ParameterAddress.scale.rawValue)!.value
		), scaleSegmentedControl!.segmentCount - 1)
		
		degreePopUpButton!.selectItem(at: min(7 - Int(
			audioUnit.parameterTree!.parameter(withAddress: HarmonizerAudioUnit.ParameterAddress.degree.rawValue)!.value
		), degreePopUpButton!.itemArray.count - 1))
		
		mixSlider!.floatValue = audioUnit.parameterTree!.parameter(withAddress: HarmonizerAudioUnit.ParameterAddress.mix.rawValue)!.value
	}
	
	private func parameterObserver(address: AUParameterAddress, value: AUValue) {
		Console.log(.default, "\(address) = \(value)")
		
		guard isViewLoaded else {
			return
		}
		guard let address = HarmonizerAudioUnit.ParameterAddress(rawValue: address) else {
			return
		}
		
		DispatchQueue.main.async {
			switch address {
			case .root:
				self.rootPopUpButton?.selectItem(at: min(Int(value), self.rootPopUpButton!.itemArray.count - 1))
			case .scale:
				self.scaleSegmentedControl?.selectedSegment = min(Int(value), self.scaleSegmentedControl!.segmentCount - 1)
			case .degree:
				self.degreePopUpButton?.selectItem(at: min(7 - Int(value), self.degreePopUpButton!.itemArray.count - 1))
			case .mix:
				self.mixSlider?.floatValue = value
			}
		}
	}
	
	@IBAction func didSetRoot(sender: NSPopUpButton) {
		guard let root = Pitch.Class(rawValue: sender.indexOfSelectedItem) else {
			return
		}
		Console.log(.default, "\(root)")
		audioUnit?.parameterTree!.parameter(withAddress: HarmonizerAudioUnit.ParameterAddress.root.rawValue)!.setValue(
			AUValue(sender.indexOfSelectedItem), originator: parameterObserverToken
		)
	}
	
	@IBAction func didSetScale(sender: NSSegmentedControl) {
		Console.log(.default, "\(sender.selectedSegment == 0 ? "major" : "minor")")
		audioUnit?.parameterTree!.parameter(withAddress: HarmonizerAudioUnit.ParameterAddress.scale.rawValue)!.setValue(
			AUValue(sender.selectedSegment), originator: parameterObserverToken
		)
	}
	
	@IBAction func didSetDegree(sender: NSPopUpButton) {
		let degree = 7 - sender.indexOfSelectedItem
		Console.log(.default, "\(degree)")
		audioUnit?.parameterTree!.parameter(withAddress: HarmonizerAudioUnit.ParameterAddress.degree.rawValue)!.setValue(
			AUValue(degree), originator: parameterObserverToken
		)
	}
	
	@IBAction func didSetMix(sender: NSSlider) {
		Console.log(.default, "\(sender.floatValue)")
		audioUnit?.parameterTree!.parameter(withAddress: HarmonizerAudioUnit.ParameterAddress.mix.rawValue)!.setValue(
			sender.floatValue, originator: parameterObserverToken
		)
	}
}
