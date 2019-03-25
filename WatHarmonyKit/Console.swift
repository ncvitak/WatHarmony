//
//  Console.swift
//  WatHarmonyKit
//
//  Created by Nicholas Cvitak on 2019-03-11.
//  Copyright © 2019 Nicholas Cvitak. All rights reserved.
//

import Foundation
import os.log

public struct Console {
	public enum LogLevel: Int {
		case fault = -2
		case error = -1
		case `default` = 0
		case info = 1
		case debug = 2
	}
	
	private static let level: LogLevel = {
		return LogLevel(rawValue: UserDefaults.standard.integer(forKey: "Console.level")) ?? .default
	}()
	
	public static func log(file: String = #file, line: Int = #line, function: String = #function, _ level: LogLevel, _ format: String, _ args: CVarArg...) {
		guard level.rawValue <= Console.level.rawValue else {
			return
		}
		let index: String.Index
		if let dir = file.lastIndex(of: "/") {
			index = file.index(after: dir)
		} else {
			index = file.startIndex
		}
		
		let formatted = String(format: "[\(level)] \(file[index..<file.endIndex]):\(line):\(function): \(format)", arguments: args)
		if #available(macOSApplicationExtension 10.14, *) {
			os_log(level.osLogType, "%{public}s", formatted)
		} else {
			formatted.withCString { cformatted in
				withVaList([cformatted] as [CVarArg]) { vargs in
					vsyslog(level.sysLogType, "%s", vargs)
				}
			}
		}
	}
}

extension Console.LogLevel: CustomStringConvertible {
	public var description: String {
		switch self {
		case .default:
			return "default"
		case .info:
			return "info"
		case .debug:
			return "debug"
		case .error:
			return "error"
		case .fault:
			return "fault"
		}
	}
}

@available(macOSApplicationExtension 10.14, *)
private extension Console.LogLevel {
	var osLogType: OSLogType {
		switch self {
		case .default:
			return .default
		case .info:
			return .info
		case .debug:
			return .debug
		case .error:
			return .error
		case .fault:
			return .fault
		}
	}
}

private extension Console.LogLevel {
	var sysLogType: Int32 {
		switch self {
		case .default:
			return LOG_NOTICE
		case .info:
			return LOG_INFO
		case .debug:
			return LOG_DEBUG
		case .error:
			return LOG_ERR
		case .fault:
			return LOG_CRIT
		}
	}
}
