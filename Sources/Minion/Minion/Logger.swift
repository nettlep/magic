//
//  Logger.swift
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

// ---------------------------------------------------------------------------------------------------------------------------------
// Global access
// ---------------------------------------------------------------------------------------------------------------------------------

/// Our global logger
public let gLogger = Logger()

/// A powerful logging class with registered devices, flexible log masks (using parsed strings with inclusion/exclusion flags) and
/// more.
///
/// To use this class, register at least one LoggerDevice, then `start()` the log and begin using the logging methods (such as
/// `info()`, `debug`, etc.) You may use `push()` and `pop()` to manage indentation during a session. To end a logging session,
/// simply call `stop()`.
public final class Logger
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Locak types
	// -----------------------------------------------------------------------------------------------------------------------------

	private struct LogEntry
	{
		var level: LogLevel
		var indent: Int
		var dateString: String
		var text: String
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Number of characters to indent at each level
	private let kIndentChars: Int = 4

	/// The default log mask, if none specified
	private let kDefaultLogMask: String = "!all"

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Our mutex used to prevent logger re-entry
	private var LogMutex = PThreadMutex()

	/// We store a queue of log entries for pre-start logs, and once the logger is started, those entries are finally logged
	private var prestartLogQueue = [LogEntry]()

	/// Our list of registered output devices
	private var outputDevices = [LogDevice]()

	/// Indentation level for log output
	private var indentLevel: Int = 0

	/// Tracks the current state of the logger
	///
	/// Use `start()` and `stop()` to control the state of the logger
	public private(set) var started = AtomicFlag()

	/// Our combined log mask, containing all log masks from all devices
	///
	/// This is a computed property wrapping `internalCombinedLogMasks` in order to apply any temporary modifications that may be
	/// set in `modifiedLogMasks`.
	public private(set) var combinedLogMasks: Int
	{
		get
		{
			return internalCombinedLogMasks | modifiedLogMasks
		}
		set
		{
			internalCombinedLogMasks = newValue
		}
	}

	/// Storage for the combined log masks - see the `combinedLogMasks` computed property for access to this data
	private var internalCombinedLogMasks: Int = LogLevel.minimumLevel

	/// Modifications to the log masks for temporarily enabling log flags (see `execute()` for details)
	private var modifiedLogMasks: Int = 0

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Default initializer for the logger
	public init()
	{
	}

	/// Initialize the logger with a set of log masks
	public init(logMasks: [String: String])
	{
		setLogMasks(logMasks: logMasks)
	}

	/// Cleans up the logger by stopping it and then closing out all logging devices
	deinit
	{
		// Stop the logger
		stop()

		// Close out each device
		for device in outputDevices
		{
			device.close()
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Logger administrative control
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Starts the logger
	///
	/// The logger must be started in order to output anything to any device
	///
	/// If `broadcastMessage` is set, the string is sent to each log device, regardless of current notification settings
	public func start(broadcastMessage: String? = nil)
	{
		if started.value { return }
		started.value = true
		if let message = broadcastMessage { broadcast(level: .Always, indent: 0, date: nil, text: message) }

		// Log anything that's in our pre-start log queue
		for entry in prestartLogQueue
		{
			broadcast(level: entry.level, indent: entry.indent, date: entry.dateString, text: entry.text)
		}

		prestartLogQueue.removeAll()
	}

	/// Stops the logger and resets any session-specific data (such as indentation level)
	///
	/// Note that this does not close out any device. Closing of devices is performed when the logger is de-initialized
	///
	/// If `broadcastMessage` is set, the string is sent to each log device, regardless of current notification settings
	public func stop(broadcastMessage: String? = nil)
	{
		if !started.value { return }
		if let message = broadcastMessage { broadcast(level: .Always, indent: 0, date: nil, text: message) }
		started.value = false

		resetIndentation()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Device management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Registers `device` as a logging output device
	/// 
	/// Note that this will call Open() on the device. If that call fails, the registration will also fail.
	/// 
	/// Also note that if a device is already registered, it will not be registered a second time (and no error will be reported.)
	public func registerDevice(device: LogDevice, logMasks: [String: String]?) -> Bool
	{
		// Try to open the device. If this fails, we won't register it.
		if !device.open() { return false }

		// Add the device
		outputDevices.append(device)

		// Update our log masks - we do this here so that the user isn't required to call `setLogMasks` after registering devices
		if logMasks != nil { setLogMasks(logMasks: logMasks!) }

		return true
	}

	/// Closes `device` and then removes it list of registered devices
	/// 
	/// If the device is not found, this method does nothing
	public func unregisterDevice(device: LogDevice)
	{
		if let deviceIndex = outputDevices.firstIndex(where: { $0.name == device.name })
		{
			device.close()
			outputDevices.remove(at: deviceIndex)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Indentation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Reset the log indent level
	public func resetIndentation()
	{
		indentLevel = 0
	}

	/// Increase the indentation of the log by one level
	///
	/// See `pop()` for to decrease indentation level
	public func push(level: LogLevel, text: String? = nil)
	{
		if let text = text { log(level, text) }

		log(level, "{")

		indentLevel += kIndentChars
	}

	/// Decrease the indentation of the log by one level (as was set by previously calling Push()).
	public func pop(level: LogLevel, text: String? = nil)
	{
		indentLevel = max(0, indentLevel - kIndentChars)

		log(level, "}")

		if let text = text { log(level, text) }
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Log output
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Logs every element in an array on a separate line with an optional header preceding the array and an optional prefix on
	/// each line of the array
	public func array<T: CustomStringConvertible>(level: LogLevel, array: [T], header: String? = nil, prefix: String = "")
	{
		var str = header != nil ? prefix + header! + String.kNewLine + String.kNewLine : ""
		for element in array
		{
			str += prefix + "  " + String(describing: element) + String.kNewLine
		}

		log(level, str)
	}

	// Our various logging shortcut methods
	@inline(__always) public func debug(_ text: String)       { if isSet(.Debug) || !started.value       { log(.Debug, text) } }
	@inline(__always) public func info(_ text: String)        { if isSet(.Info) || !started.value        { log(.Info, text) } }
	@inline(__always) public func warn(_ text: String)        { if isSet(.Warn) || !started.value        { log(.Warn, text) } }
	@inline(__always) public func error(_ text: String)       { if isSet(.Error) || !started.value       { log(.Error, text) } }
	@inline(__always) public func severe(_ text: String)      { if isSet(.Severe) || !started.value      { log(.Severe, text) } }
	@inline(__always) public func fatal(_ text: String)       { if isSet(.Fatal) || !started.value       { log(.Fatal, text) } }
	@inline(__always) public func trace(_ text: String)       { if isSet(.Trace) || !started.value       { log(.Trace, text) } }
	@inline(__always) public func perf(_ text: String)        { if isSet(.Perf) || !started.value        { log(.Perf, text) } }
	@inline(__always) public func status(_ text: String)      { if isSet(.Status) || !started.value      { log(.Status, text) } }
	@inline(__always) public func frame(_ text: String)       { if isSet(.Frame) || !started.value       { log(.Frame, text) } }
	@inline(__always) public func search(_ text: String)      { if isSet(.Search) || !started.value      { log(.Search, text) } }
	@inline(__always) public func decode(_ text: String)      { if isSet(.Decode) || !started.value      { log(.Decode, text) } }
	@inline(__always) public func resolve(_ text: String)     { if isSet(.Resolve) || !started.value     { log(.Resolve, text) } }
	@inline(__always) public func badResolve(_ text: String)  { if isSet(.BadResolve) || !started.value  { log(.BadResolve, text) } }
	@inline(__always) public func correct(_ text: String)     { if isSet(.Correct) || !started.value     { log(.Correct, text) } }
	@inline(__always) public func incorrect(_ text: String)   { if isSet(.Incorrect) || !started.value   { log(.Incorrect, text) } }
	@inline(__always) public func result(_ text: String)      { if isSet(.Result) || !started.value      { log(.Result, text) } }
	@inline(__always) public func badReport(_ text: String)   { if isSet(.BadReport) || !started.value   { log(.BadReport, text) } }
	@inline(__always) public func network(_ text: String)     { if isSet(.Network) || !started.value     { log(.Network, text) } }
	@inline(__always) public func networkData(_ text: String) { if isSet(.NetworkData) || !started.value { log(.NetworkData, text) } }
	@inline(__always) public func video(_ text: String)       { if isSet(.Video) || !started.value       { log(.Video, text) } }
	@inline(__always) public func always(_ text: String)      { if isSet(.Always) || !started.value      { log(.Always, text) } }

	/// The primary logging method
	///
	/// Generally, you would use one of the log methods specific to a log level (such as `debug(text:)` or `status(text:)`) rather
	/// than using this method directly. However, sometimes if the log level is parametric, then use this method to provide the
	/// log level.
	public func log(_ level: LogLevel, _ text: String)
	{
		let now = String.conciseTimestamp(date: Date())
		let lines = text.split(on: String.kNewLine)

		LogMutex.fastsync
		{
			for line in lines
			{
				self.broadcast(level: level, indent: self.indentLevel, date: now, text: line)
			}
		}
	}

	/// Broadcasts a raw string to all log devices, regardless of the current logging level
	@inline(__always) private func broadcast(level: LogLevel, indent: Int, date: String? = nil, text: String)
	{
		let dateString = date ?? String.conciseTimestamp()

		// If we're not started, add it to our pre-start queue
		if !started.value
		{
			prestartLogQueue.append(LogEntry(level: level, indent: indent, dateString: dateString, text: text))
			return
		}

		for device in outputDevices
		{
			// Get the device's log mask, with additional modifications applied
			let mask = device.mask | modifiedLogMasks

			// Ensure our mask is set
			if (mask & level.rawValue) == 0 { continue }

			device.write(level: level, indent: indent, date: dateString, text: text)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Log mask parsing and management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Executes a code block with a custom LogLevel enabled
	///
	/// The LogLevel defined by the combined bits of `mask` are enabled (via the use of a bitwise OR operation) globally
	/// to all devices prior to executing `block` and restored afterwards.
	public func execute<Result>(with level: LogLevel, block: @escaping () -> Result) -> Result
	{
		return self.execute(with: level.rawValue, block: block)
	}

	/// Executes a code block with a custom set of additional log levels enabled
	///
	/// The set of LogLevels defined by the combined bits of `mask` are enabled (via the use of a bitwise OR operation) globally
	/// to all devices prior to executing `block` and restored afterwards.
	public func execute<Result>(with mask: Int, block: @escaping () -> Result) -> Result
	{
		// Save off our current modified log masks
		let savedModifiedLogMasks = modifiedLogMasks

		// Set the new masks
		modifiedLogMasks = mask

		// Run the block
		let result = block()

		// Restore them
		modifiedLogMasks = savedModifiedLogMasks

		// Run the block
		return result
	}

	/// Set or update the log masks to use for all devices
	///
	/// IMPORTANT: Be sure to call this after registering devices
	///
	/// This method also sets the `combinedLogMasks` property
	public func setLogMasks(logMasks: [String: String])
	{
		// Default for our combined log masks
		combinedLogMasks = LogLevel.minimumLevel

		// Apply the mask to each device
		if let masks = logMasks.lowercasedKeys()
		{
			for i in 0..<outputDevices.count
			{
				// Find the mask for the requested device first and if not found, use the default mask
				let deviceMask = masks[outputDevices[i].name.lowercased()] ?? kDefaultLogMask
				let parsed = LogLevel.parsedFrom(string: deviceMask) | LogLevel.minimumLevel
				combinedLogMasks |= parsed
				outputDevices[i].mask = parsed | LogLevel.minimumLevel
			}
		}
	}

	/// Returns true if `level` is set in any of the registered devices
	@inline(__always) public func isSet(_ level: LogLevel) -> Bool
	{
		return (combinedLogMasks & level.rawValue) == level.rawValue
	}

	/// Returns true if any bit of `mask` matches the mask of any of the registered devices
	@inline(__always) public func isSet(_ mask: Int) -> Bool
	{
		return (combinedLogMasks & mask) != 0
	}
}
