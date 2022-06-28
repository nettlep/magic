//
//  LogDevice.swift
//  Seer
//
//  Created by Paul Nettle on 3/24/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// Defines a device that receives the output from the logger.
///
/// Devices may be defined for various media, such as a standard log file, a system log, a cloud-based log tracking service, etc.
///
/// These devices are then added to the logging service via RegisterDevice() and UnregisterDevice() methods in the Logger class.
///
/// Note that if a device fails to open, it will not be registered.
public protocol LogDevice
{
	/// The mask set for this device
	var mask: Int { get set }

	/// The name of this device
	var name: String { get }

	/// Opens the target output device.
	///
	/// If this function fails, it will not get registered.
	///
	/// Returns true on success, otherwise false
	func open() -> Bool

	/// Writes a log entry to the output device
	func write(level: LogLevel, indent: Int, date: String, text: String)

	/// Closes the target output device
	func close()
}
