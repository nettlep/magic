//
//  LogDeviceTextUi.swift
//  Seer
//
//  Created by Paul Nettle on 3/24/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#if os(macOS) || os(Linux)

import Foundation
import Minion

/// A logging device that logs directly to the text-based UI in Seer (`TextUi`)
public final class LogDeviceTextUi: LogDevice
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The mask set for this device
	public var mask: Int = 0

	/// Returns the name of this device
	public var name: String { return "UI" }

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

	// -----------------------------------------------------------------------------------------------------------------------------

	/// Writes a log entry to the output device
	public func write(level: LogLevel, indent: Int, date: String, text: String)
	{
		let indentString = String(repeating: " ", count: indent)
		//let levelString = (level == .Warn || level == .Error || level == .Severe || level == .Fatal) ? "[\(level)] " : ""
		let levelString = "[\(level)] "
		TextUi.instance.logLine("\(levelString)\(indentString)\(text)\n")
	}

	// -----------------------------------------------------------------------------------------------------------------------------

	/// Closes the target output device
	public func close()
	{
		// Nothing to do here
	}
}

#endif // os(macOS) || os(Linux)
