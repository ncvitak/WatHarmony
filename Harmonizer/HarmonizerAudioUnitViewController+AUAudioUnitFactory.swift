//
//  HarmonizerAudioUnitViewController+AUAudioUnitFactory.swift
//  WatHarmony.Harmonizer
//
//  Created by Nicholas Cvitak on 2019-03-11.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

import AudioToolbox
import WatHarmonyKit

extension HarmonizerAudioUnitViewController: AUAudioUnitFactory {
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
		Console.log(.default, "")
        audioUnit = try HarmonizerAudioUnit(componentDescription: componentDescription, options: [])
        return audioUnit!
    }
}
