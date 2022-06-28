//
//  LogLevel.swift
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

/// Various log levels associated to an individual log entry
///
/// These can be enabled and disabled in the Logger
public enum LogLevel: Int
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Log levels
	// -----------------------------------------------------------------------------------------------------------------------------

	/// A special log level that represents all log levels being not set
	case None        = 0

	/// A log level used for debug information - these logs should be temporary
	case Debug       = 0b1

	/// A log level used for standard informational messages
	///
	/// This is a catch-all; avoid this unless absolutely necessary
	case Info        = 0b10

	/// A log level for warning messages
	///
	/// DEFINITION: A warning is defined as an issue that should be investigated
	///             Warnings are often a sign of a condition in the logic or data that wasn't accounted for
	///
	/// * MAY result in an error, but not necessarily (investigate!)
	/// * MAY have a negative impact on the application's ability to function as intended
	/// * MAY impact application stability
	case Warn        = 0b100

	/// A log level for errors
	///
	/// DEFINITION: An error is defined as a problem that should be fixed
	///
	/// * MAY have a negative impact on the application's ability to function as intended
	/// * MAY impact application stability
	case Error       = 0b1000

	/// A log level for severe errors
	///
	/// DEFINITION: A severe error is defined as a problem that
	///
	/// * WILL have a negative impact on the application's ability to function as intended
	/// * MAY impact application stability
	case Severe      = 0b10000

	/// A log level for fatal errors
	///
	/// DEFINITION: A fatal error is defined as a problem that prevents the application from continuing to run
	///
	/// * WILL impact application stability
	case Fatal       = 0b100000

	/// A log level used for tracing code paths
	case Trace       = 0b1000000

	/// A log level used for performance information
	case Perf        = 0b10000000

	/// A log level used for application status information
	case Status      = 0b100000000

	/// A log level used for application video frame processing
	case Frame       = 0b1000000000

	/// A log level for the the deck search process
	case Search      = 0b10000000000

	/// A log level for the deck decoding process
	case Decode      = 0b100000000000

	/// A log level for the resolve process
	case Resolve     = 0b1000000000000

	/// A log level for errors during the resolve process
	case BadResolve  = 0b10000000000000

	/// A log level for results verified as correct
	case Correct     = 0b0100000000000000
	/// A log level for results verified as incorrect
	case Incorrect   = 0b1000000000000000
	/// A log level for both results (correct & incorrect)
	case Result      = 0b1100000000000000

	/// A log level for reports that were invalid
	case BadReport   = 0b10000000000000000

	/// A log level for low-frequency network activity (connections, low-frequency messages, etc.) This does not include any network data traffic.
	case Network     = 0b100000000000000000

	/// A log level for high-frequency network activity such as data packets and high-frequency messages like pings.
	case NetworkData = 0b1000000000000000000

	/// A log level for reports that were invalid
	case Video       = 0b10000000000000000000

	/// A special log level used to cause the log entry to always appear on all devices
	case Always      = 0b100000000000000000000

	/// A special log level that represents all log levels
	case All         = -1

	/// The minimum level allowed, containing the entries that must always be present
	public static var minimumLevel: Int
	{
		return
			LogLevel.Warn.rawValue |
			LogLevel.Error.rawValue |
			LogLevel.Severe.rawValue |
			LogLevel.Fatal.rawValue |
			LogLevel.Always.rawValue
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Conversion to/from String
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns a LogLevel from a string representation of a single LogLevel enumeration name
	///
	/// This operation is case-insensitive. If the string does not match the name of any of the enumerations, then `.None` is
	/// returned.
	public static func from(string str: String) -> LogLevel
	{
		switch str.lowercased()
		{
			case "debug":       return LogLevel.Debug
			case "info":        return LogLevel.Info
			case "warn":        return LogLevel.Warn
			case "error":       return LogLevel.Error
			case "severe":      return LogLevel.Severe
			case "fatal":       return LogLevel.Fatal
			case "trace":       return LogLevel.Trace
			case "perf":        return LogLevel.Perf
			case "status":      return LogLevel.Status
			case "frame":       return LogLevel.Frame
			case "search":      return LogLevel.Search
			case "decode":      return LogLevel.Decode
			case "resolve":     return LogLevel.Resolve
			case "badresolve":  return LogLevel.BadResolve
			case "correct":     return LogLevel.Correct
			case "incorrect":   return LogLevel.Incorrect
			case "result":      return LogLevel.Result
			case "badreport":   return LogLevel.BadReport
			case "network":     return LogLevel.Network
			case "networkdata": return LogLevel.NetworkData
			case "video":       return LogLevel.Video
			case "always":      return LogLevel.Always
			case "all":         return LogLevel.All
			default:            return .None
		}
	}

	/// Returns a string containing all LogLevels that appear in the given `mask`
	public static func maskString(_ mask: Int) -> String
	{
		if mask == LogLevel.None.rawValue
		{
			return "None"
		}
		else if mask & LogLevel.All.rawValue == LogLevel.All.rawValue
		{
			return "All"
		}

		var combined = ""
		if (mask & LogLevel.Debug.rawValue)       == LogLevel.Debug.rawValue       { combined += "Debug " }
		if (mask & LogLevel.Info.rawValue)        == LogLevel.Info.rawValue        { combined += "Info " }
		if (mask & LogLevel.Warn.rawValue)        == LogLevel.Warn.rawValue        { combined += "Warn " }
		if (mask & LogLevel.Error.rawValue)       == LogLevel.Error.rawValue       { combined += "Error " }
		if (mask & LogLevel.Severe.rawValue)      == LogLevel.Severe.rawValue      { combined += "Severe " }
		if (mask & LogLevel.Fatal.rawValue)       == LogLevel.Fatal.rawValue       { combined += "Fatal " }
		if (mask & LogLevel.Trace.rawValue)       == LogLevel.Trace.rawValue       { combined += "Trace " }
		if (mask & LogLevel.Perf.rawValue)        == LogLevel.Perf.rawValue        { combined += "Perf " }
		if (mask & LogLevel.Status.rawValue)      == LogLevel.Status.rawValue      { combined += "Status " }
		if (mask & LogLevel.Frame.rawValue)       == LogLevel.Frame.rawValue       { combined += "Frame " }
		if (mask & LogLevel.Search.rawValue)      == LogLevel.Search.rawValue      { combined += "Search " }
		if (mask & LogLevel.Decode.rawValue)      == LogLevel.Decode.rawValue      { combined += "Decode " }
		if (mask & LogLevel.Resolve.rawValue)     == LogLevel.Resolve.rawValue     { combined += "Resolve " }
		if (mask & LogLevel.BadResolve.rawValue)  == LogLevel.BadResolve.rawValue  { combined += "BadResolve " }
		if (mask & LogLevel.Result.rawValue)      == LogLevel.Result.rawValue      { combined += "Result " }
		if (mask & LogLevel.Correct.rawValue)     == LogLevel.Correct.rawValue     { combined += "Correct " }
		if (mask & LogLevel.Incorrect.rawValue)   == LogLevel.Incorrect.rawValue   { combined += "Incorrect " }
		if (mask & LogLevel.BadReport.rawValue)   == LogLevel.BadReport.rawValue   { combined += "BadReport " }
		if (mask & LogLevel.Network.rawValue)     == LogLevel.Network.rawValue     { combined += "Network " }
		if (mask & LogLevel.NetworkData.rawValue) == LogLevel.NetworkData.rawValue { combined += "NetworkData " }
		if (mask & LogLevel.Video.rawValue)       == LogLevel.Video.rawValue       { combined += "Video " }
		if (mask & LogLevel.Always.rawValue)      == LogLevel.Always.rawValue      { combined += "Always " }
		return combined.trim()
	}

	/// Returns a short-code string containing all LogLevels that appear in the given `mask`
	public static func maskCode(_ mask: Int) -> String
	{
		if mask == LogLevel.None.rawValue
		{
			return "None"
		}
		else if mask & LogLevel.All.rawValue == LogLevel.All.rawValue
		{
			return "+All"
		}

		var combined = ""
		if (mask & LogLevel.Debug.rawValue)       == LogLevel.Debug.rawValue      { combined += "Dbug " }
		if (mask & LogLevel.Info.rawValue)        == LogLevel.Info.rawValue       { combined += "Info " }
		if (mask & LogLevel.Warn.rawValue)        == LogLevel.Warn.rawValue       { combined += "Warn " }
		if (mask & LogLevel.Error.rawValue)       == LogLevel.Error.rawValue      { combined += "Errr " }
		if (mask & LogLevel.Severe.rawValue)      == LogLevel.Severe.rawValue     { combined += "Sevr " }
		if (mask & LogLevel.Fatal.rawValue)       == LogLevel.Fatal.rawValue      { combined += "Fatl " }
		if (mask & LogLevel.Trace.rawValue)       == LogLevel.Trace.rawValue      { combined += "Trce " }
		if (mask & LogLevel.Perf.rawValue)        == LogLevel.Perf.rawValue       { combined += "Perf " }
		if (mask & LogLevel.Status.rawValue)      == LogLevel.Status.rawValue     { combined += "Stat " }
		if (mask & LogLevel.Frame.rawValue)       == LogLevel.Frame.rawValue      { combined += "Fram " }
		if (mask & LogLevel.Search.rawValue)      == LogLevel.Search.rawValue     { combined += "Srch " }
		if (mask & LogLevel.Decode.rawValue)      == LogLevel.Decode.rawValue     { combined += "Dcod " }
		if (mask & LogLevel.Resolve.rawValue)     == LogLevel.Resolve.rawValue    { combined += "Rslv " }
		if (mask & LogLevel.BadResolve.rawValue)  == LogLevel.BadResolve.rawValue { combined += "BRes " }
		if (mask & LogLevel.Result.rawValue)      == LogLevel.Result.rawValue     { combined += "Rslt " }
		if (mask & LogLevel.Correct.rawValue)     == LogLevel.Correct.rawValue    { combined += "Corr " }
		if (mask & LogLevel.Incorrect.rawValue)   == LogLevel.Incorrect.rawValue  { combined += "Incr " }
		if (mask & LogLevel.BadReport.rawValue)   == LogLevel.BadReport.rawValue  { combined += "BRep " }
		if (mask & LogLevel.Network.rawValue)     == LogLevel.Network.rawValue    { combined += "Netw " }
		if (mask & LogLevel.NetworkData.rawValue) == LogLevel.Network.rawValue    { combined += "Data " }
		if (mask & LogLevel.Video.rawValue)       == LogLevel.Video.rawValue      { combined += "Vido " }
		if (mask & LogLevel.Always.rawValue)      == LogLevel.Always.rawValue     { combined += "Alwy " }
		return combined.trim()
	}

	/// Parses a string of LogLevel values into a set of bits representing the parsed set
	///
	/// `string` contains names of the various log levels (such as "Info", "Warn", "Err", etc.) separated by spaces. Starting with
	/// an empty working set of LogLevels, `string` is parsed from left to right and each entry encountered modifies the working
	/// set of log levels. For example:
	///
	///		"!All Warn Error Fatal"
	///
	///	...will disable all log levels (which is the default starting value) and then enable `Warn`, `Err` and `Fatal` levels.
	///
	/// Removing a LogLevel from the set is possible by prefixing a LogLevel name with a "!" (as in "!Info"). For example, logging
	/// everything except `Info` can be achieved via "All !Info".
	///
	/// Note that '!None' results in a NOP as it removes `.None`. If the intention is to clear all entries, use '!All'.
	///
	/// This operation is case-insensitive.
	public static func parsedFrom(string: String) -> Int
	{
		// Setup our new cached set of log levels
		var result: Int = 0

		// Cleanup and split the string
		let elements = string.trim().lowercased().split()

		// Scan the elements in the string from start to end
		for element in elements
		{
			let remove = element.hasPrefix("!")
			let value = from(string: remove ? element.firstRemoved() : element).rawValue

			// Apply it to our result
			if remove
			{
				result &= value ^ LogLevel.All.rawValue
			}
			else
			{
				result |= value
			}
		}

		return result
	}

}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension LogLevel: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		return LogLevel.maskCode(rawValue)
	}
}
