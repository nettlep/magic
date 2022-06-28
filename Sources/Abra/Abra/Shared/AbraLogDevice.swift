//
//  AbraLogDevice.swift
//  Abra
//
//  Created by Paul Nettle on 10/5/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import SwiftUI
#if os(iOS)
import SeerIOS
import MinionIOS
import NativeTasksIOS
#else
import Seer
import Minion
import NativeTasks
#endif

struct LogLine {
	var date: String
	var level: LogLevel
	var text: String

	func toString() -> String {
		return "\(date) [\(level)] \(text)"
	}
}

class LogData: ObservableObject {
	private static let kPublishFrequencyMS: Double = 200

	private let linesMutex = PThreadMutex()

	private var _lines = [LogLine]()
	private var publishScheduled = false

	private(set) var longestLine = ""
	private(set) var longestLineLength = 0

	public func clear()
	{
		linesMutex.fastsync
		{
			longestLine = ""
			longestLineLength = 0
			_lines = [LogLine]()
		}

		objectWillChange.send()
	}

	public func addLine(date: String, level: LogLevel, text: String)
	{
		linesMutex.fastsync
		{
			let line = LogLine(date: date, level: level, text: text)
			let length = text.length()
			if length > longestLineLength
			{
				longestLine = line.toString()
				longestLineLength = length
			}

			_lines.append(line)
			schedulePublish()
		}
	}

	/// Schedules a publish
	///
	/// NOTE! This method should only be called inside a mutex sync
	private func schedulePublish()
	{
		if publishScheduled { return }

		DispatchQueue.main.asyncAfter(deadline: .now() + LogData.kPublishFrequencyMS / 1000)
		{
			self.objectWillChange.send()
		}
	}

	public var lines: [LogLine]
	{
		linesMutex.fastsync
		{
			return _lines
		}
	}
}

public final class AbraLogDevice: LogDevice
{
	static let logData = LogData()

	/// The mask set for this device
	public var mask: Int = 0

	/// Returns the name of this device
	public var name: String { return "UI" }

	/// Default initializer - we need this here so we can declare it as public
	public init()
	{

	}

	/// Opens the target output device
	public func open() -> Bool
	{
		// Noting to do here
		return true
	}

	/// Writes a log entry to the output device
	public func write(level: LogLevel, indent: Int, date: String, text: String)
	{
		let indentString = String(repeating: " ", count: indent)
		let prefix = "\(indentString)"

		DispatchQueue.main.async
		{
			AbraLogDevice.logData.addLine(date: date, level: level, text: prefix + text)
		}
	}

	/// Closes the target output device
	public func close()
	{
		// Nothing to do here
	}
}
