//
//  LogDeviceFile.swift
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
import Dispatch

public final class LogDeviceFile: LogDevice
{
	/// The mask set for this device
	public var mask: Int = 0

	/// Synchronization dispatch queue
	private let dispatchQueue = DispatchQueue(label: "com.paulnettle.seer.LogDeviceFile")

	/// The configured log file locations (the first successful will be used)
	private var logFileLocations: [PathString]

	/// If true, the log file will be truncated when opened
	private var truncate: Bool = false

	/// Our file manager, used for creating, removing and validating existence of the log file
	private var fileManager = FileManager()

	/// The file handle used to write to our log file
	private var logFileHandle: FileHandle?

	/// Returns true if the log file was opened, otherwise false
	public var opened: Bool { return logFileHandle != nil }

	/// Returns the name of this device
	public var name: String { return "File" }

	/// The path of the currently opened log file, or nil
	private var logFilePath: PathString?

	/// Initialize a LogDeviceFile with a path, optionally truncating the file if it exists
	///
	/// If `path` is not provided, the config value `log.FilePath` is used
	/// if `truncate` is not provided, the config value `log.ResetOnStart` is used
	public init(logFileLocations: [PathString], truncate: Bool)
	{
		self.logFileLocations = logFileLocations
		self.truncate = truncate
	}

	/// Cleans up the LogDeviceFile
	deinit
	{
		close()
	}

	/// Opens the target output device based on the array `logFileLocations`
	/// 
	/// If this function fails, the device will not get registered.
	/// 
	/// Returns true on success, otherwise false
	public func open() -> Bool
	{
		// Ensure the previous file was closed
		close()

		// Open the file
		return dispatchQueue.sync
		{
			// Ensure we didn't have a race condition getting into this dispatch queue
			if opened { return false }

			for logFileLocation in logFileLocations
			{
				// Get the absolute path (this also performs home-directory expansion)
				let path = logFileLocation.toAbsolutePath()

				if path.isDirectory()
				{
					gLogger.debug("Skipping log file ('\(path)'), because it is a directory")
					continue
				}

				if path.isFile()
				{
					if truncate
					{
						if !path.createFile()
						{
							gLogger.debug("Skipping log file ('\(path)'), unable to truncate file")
							continue
						}
					}
				}
				else
				{
					// Ensure the directory containing the log file exists
					if let dir = path.withoutLastComponent()
					{
						if !dir.createDirectory()
						{
							gLogger.debug("Skipping log file ('\(path)'), unable to create directory")
							continue
						}
					}

					// Create the file
					if !path.createFile()
					{
						gLogger.debug("Skipping log file ('\(path)'), unable to create file")
						continue
					}
				}

				// We should have a file to open
				guard let handle = FileHandle(forWritingAtPath: path.toString()) else
				{
					gLogger.debug("Skipping log file ('\(path)'), unable to open file")
					continue
				}

				logFileHandle = handle
				logFilePath = path
				_ = logFileHandle?.seekToEndOfFile()
				gLogger.info("Log file opened at path '\(path)'")
				return true
			}

			gLogger.error("Unable to register file logging device - none of the given log locations could be used")
			return false
		}
	}

	/// Writes a log entry to the output device
	public func write(level: LogLevel, indent: Int, date: String, text: String)
	{
		let indentString = String(repeating: " ", count: indent)
		let prefix = "\(date) [\(level)] \(indentString)"

		// Ensure the file is opened
		if !opened { return }

		if let logLine = (prefix + text + String.kNewLine).data(using: .utf8)
		{
			dispatchQueue.sync
			{
				// We still use the optional chaining in case there was a race condition getting into this dispatch queue
				logFileHandle?.write(logLine)

				// Flulsh the file - good for trapping crashes
				logFileHandle?.synchronizeFile()
			}
		}
	}

	/// Closes the target output device
	public func close()
	{
		if !opened { return }

		dispatchQueue.sync
		{
			// We still use the optional chaining in case there was a race condition getting into this dispatch queue
			logFileHandle?.closeFile()
			logFileHandle = nil
			logFilePath = nil
		}
	}
}
