//
//  LogDeviceGeneric.swift
//  Minion
//
//  Created by Paul Nettle on 3/24/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// A generic logging device that caches log lines, useful for systems that updated on a periodic basis, such as most UIs
///
/// Log lines can be retrieved via the `getLogLines` method
public final class LogDeviceGeneric: LogDevice
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The mask set for this device
	public var mask: Int = 0

	/// Returns the name of this device
	public var name: String { return "UI" }

	/// The log lines that are to get appended to the end of the log.
	///
	/// To access them, call `getLogLines(reset:)`
	private(set) var cachedLogLines = Atomic<String>("")

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

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
		let levelString = (level == .Warn || level == .Error || level == .Severe || level == .Fatal) ? "[\(level)] " : ""
		cachedLogLines.mutate { $0 += levelString + "\(indentString)\(text)\r\n" }
	}

	/// Closes the target output device
	public func close()
	{
		// Nothing to do here
	}

	/// Returns the new log lines that were appended to the log since the previous reset
	///
	/// The returned string may be empty if no log data exists
	public func getLogLines(reset: Bool = true) -> String
	{
		if cachedLogLines.value.isEmpty { return "" }
		let str = cachedLogLines.value
		if reset
		{
			cachedLogLines.mutate { $0.removeAll(keepingCapacity: true) }
		}
		return str
	}
}
