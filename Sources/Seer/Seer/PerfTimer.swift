//
//  PerfTimer.swift
//  Seer
//
//  Created by Paul Nettle on 11/16/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
#if os(iOS)
import MinionIOS
#else
import Minion
#endif

/// A global variable used by the PerfTimer class in order to ensure its lifetime
var globalVar = 0

/// A class used to track performance information related to the time spent performing various serial operations. This class should
/// not be instantiated as it contains class methods.
///
/// The PerfTimer records all time between calls to start() and stop(). During that time, a block of code can be individually
/// monitored by calling track() like so:
///
/// 		PerfTimer.track("Call to doSomething")
///			{ { () -> CVPixelBuffer? in
///				do_something()
///			}
///
/// In cases where the calculation of a value is being tracked, it may be necessary to return that value from within the scope of
/// the tracking closure. Here is a simple example:
///
/// 		return PerfTimer.track("Call to doSomething", operation:
///			{
///				let foo = calculate_something()
///				return foo
///			})
///
/// In some cases, the return type is too complex for the compiler to infer the return type. The solution is thus:
///
/// 		return PerfTimer.track("Call to doSomething", operation:
///			{ () -> SomeType? in
///				let foo = calculate_something()
///				return foo
///			})
///
/// Use reset() to nullify the state of the PerfTimer to an initial, non-started state.
///
/// Use logStats() to display the stats. Note that calling logStats() will stop the PerfTimer.
public final class PerfTimer
{
	/// Stores the information for a sampled block of code
	public struct Sample
	{
		public var count: Int = 0
		public var totalMS: Real = 0
		public var minMS: Real = 0
		public var maxMS: Real = 0
		public var lastMS: Real = 0
		public var averageMS: Real { return totalMS / Real(count) }
	}

	/// Used to track objects within a scope
	///
	/// Declare this object at some point in a scoped block of code and when that scope ends, this object will deinit,
	/// automatically stopping the timer and recording the event time.
	///
	/// Be careful to take note of this object's use in blocks and other situations where object cleanup is altered from normal
	/// expectations. Ensure to call the `use()` method at some point after constructing this object. This prevents the Swift
	/// optimizer from destructing the object immediately after creation.
	///
	/// Example usage:
	///
	///		func doSomething()
	///		{
	///			let _track_ = PerfTimer.ScopedTrack(name: "Doing something..."); _track_.use()
	///
	///			... do something ...
	///
	///		}
	///
	/// If you want to track a block of code within a function, you can use the `do {}` construct to provide ad-hoc scopes, like so:
	///
	///		do
	///		{
	///			let _track_ = PerfTimer.ScopedTrack(name: "Doing something..."); _track_.use()
	///
	///			... do something ...
	///
	///		}
	public final class ScopedTrack
	{
		/// The name of the tracking event
		private(set) var name: String

		/// The start time of the tracking event
		public let start: Time

		/// Initialize a new tracking event and being tracking
		///
		public init(name: String)
		{
			self.name = name
			self.start = PerfTimer.trackBegin()
		}

		/// De-initialize the object and stop tracking
		deinit
		{
			stopTracking()
		}

		/// Required to trick the Swift compiler into not destructing this object right away. Be sure to call this within the scope
		/// at some point after construction. See class notes for `ScopedTrack` for more information.
		public func use()
		{
			globalVar += 1
		}

		/// Stops tracking and records the event
		private func stopTracking()
		{
			PerfTimer.trackEnd(name: name, start: start)
		}
	}

	/// The samples for various blocks of code. Each entry contains the name of the block and the sample for that block. By
	/// storing the name of the block, it can be located in order to accumulate all execution samples.
	public static var blockTimes: [String: Sample] = [:]

	/// The start time of performance monitoring for tracking the total elapsed time in order to provide overall block execution
	/// percentages. Times are stored in milliseconds since epoch.
	public static var startTimeMS: Time = 0

	/// The total measured time, representing the portion of the total time of performance monitoring (see startTime) which is
	/// actually monitored by one block or another. Times are stored in milliseconds since epoch.
	public static var measuredTimeMS: Time = 0

	/// Flag to denote if the performance timer has been started
	public class var started: Bool { return startTimeMS > 0 }

	/// Our lock queue label for multithreaded access to the blockTimes
	private static let BlockTimesMutex = PThreadMutex()

	/// Start (or restart) the PerfTimer. If the PerfTimer has already been started, an additional call will effectively
	/// restart it, clearing out all data and starting the PerfTimer from scratch.
	public class func start()
	{
		reset()
		startTimeMS = PausableTime.getTimeMS()
	}

	/// Stops the PerfTimer. This does not clear out any captured data. Once the PerfTimer has been stopped, it can not
	/// be continued, it must be started via a call to start().
	public class func stop()
	{
		let stopTimeMS = PausableTime.getTimeMS()
		measuredTimeMS = stopTimeMS - startTimeMS
		startTimeMS = 0
	}

	/// Track a block of code specified by operation. The block name allows multiple executions of the same block to be accumulated
	/// for complete stats over multiple executions.
	public class func track<Result>(_ name: String, operation: () -> Result) -> Result
	{
		let start = trackBegin()
		let result = operation()
		trackEnd(name: name, start: start)
		return result
	}

	/// Begins a tracked event and returns the starting time (in milliseconds since epoch.)
	///
	/// To end a tracked event, see trackEnd(name:start:)
	public class func trackBegin() -> Time
	{
		return PausableTime.getTimeMS()
	}

	/// Ends a tracked event, adding the named event to the captured data
	///
	/// The `start` parameter should be the value received from trackBegin()
	public class func trackEnd(name: String, start: Time)
	{
		let delta = Real(PausableTime.getTimeMS() - start)
		BlockTimesMutex.fastsync
		{
			if var sample = blockTimes[name]
			{
				sample.count += 1
				sample.totalMS += delta
				sample.minMS = min(delta, sample.minMS)
				sample.maxMS = max(delta, sample.maxMS)
				sample.lastMS += delta
				blockTimes[name] = sample
			}
			else
			{
				blockTimes[name] = Sample(count: 1, totalMS: delta, minMS: delta, maxMS: delta, lastMS: delta)
			}
		}
	}

	/// Reset the PerfTimer to an initial state. If the PerfTimer had been started previously, this call will nullify that session
	/// and clear out any data previously captured.
	public class func reset()
	{
		BlockTimesMutex.fastsync
		{
			blockTimes = [:]
		}
		startTimeMS = 0
		measuredTimeMS = 0
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Statistics
	// -----------------------------------------------------------------------------------------------------------------------------

	private class func getStat(name: String, useAverage: Bool) -> Real?
	{
		guard let stat = PerfTimer.getStat(name: name) else { return nil }
		return useAverage ? stat.averageMS:stat.lastMS
	}

	/// Dumps a formatted line of text for performance statistics
	public class func generatePerfStatsText(useAverage: Bool = true) -> String
	{
		// Update our status
		var timing = ""

		BlockTimesMutex.fastsync
		{
			let aMS = getStat(name: "a", useAverage: useAverage)
			let bMS = getStat(name: "b", useAverage: useAverage)
			let cMS = getStat(name: "c", useAverage: useAverage)
			let dMS = getStat(name: "d", useAverage: useAverage)
			let eMS = getStat(name: "e", useAverage: useAverage)
			let fMS = getStat(name: "f", useAverage: useAverage)
			let fullFrameMS = Float(getStat(name: "Full frame", useAverage: useAverage) ?? 0)
			let videoDecodeMS = Float(getStat(name: "Video decode", useAverage: useAverage) ?? 0)
			let debugMS = Float(getStat(name: "Debug", useAverage: useAverage) ?? 0)
			let scanMS = Float(getStat(name: "Scan", useAverage: useAverage) ?? 0)
			var searchMS = Float(getStat(name: "Deck Search", useAverage: useAverage) ?? 0)
			let traceMS = Float(getStat(name: "Trace marks", useAverage: useAverage) ?? 0)
			var decodeMS = Float(getStat(name: "Deck Decode", useAverage: useAverage) ?? 0)
			let mergeMS = Float(getStat(name: "Merge History", useAverage: useAverage) ?? 0)
			let resolveMS = Float(getStat(name: "Resolve", useAverage: useAverage) ?? 0)

			// Some stats are embedded within others, so they need to be subtracted out
			searchMS -= traceMS
			decodeMS -= mergeMS
			decodeMS -= resolveMS

			if let tmp = aMS { timing += String(format: "a%.1f ", arguments: [Float(tmp)]) }
			if let tmp = bMS { timing += String(format: "b%.1f ", arguments: [Float(tmp)]) }
			if let tmp = cMS { timing += String(format: "c%.1f ", arguments: [Float(tmp)]) }
			if let tmp = dMS { timing += String(format: "d%.1f ", arguments: [Float(tmp)]) }
			if let tmp = eMS { timing += String(format: "e%.1f ", arguments: [Float(tmp)]) }
			if let tmp = fMS { timing += String(format: "f%.1f ", arguments: [Float(tmp)]) }
			timing += String(format: "%4.1f", arguments: [fullFrameMS])
			timing += String(format: " vid:%4.1f", arguments: [videoDecodeMS])
			timing += String(format: " dbg:%4.1f", arguments: [debugMS])
			timing += String(format: " scn:%6.3f", arguments: [scanMS])
			timing += " ("
			timing += String(format: "sch:%5.2f", arguments: [searchMS])
			timing += String(format: " trc:%5.2f", arguments: [traceMS])
			timing += String(format: " dec:%5.2f", arguments: [decodeMS])
			timing += String(format: " mrg:%5.2f", arguments: [mergeMS])
			timing += String(format: " res:%5.2f", arguments: [resolveMS])
			timing += ")"

			if let reportMS = getStat(name: "Report", useAverage: useAverage)
			{
				timing += String(format: " rprt:%4.1f", arguments: [Float(reportMS)])
			}
			if let uiMS = getStat(name: "TextUi", useAverage: useAverage)
			{
				timing += String(format: " ui:%4.1f", arguments: [Float(uiMS)])
			}
		}

		return timing
	}

	// Reset our stats for the next frame
	public class func nextFrame()
	{
		BlockTimesMutex.fastsync
		{
			for key in blockTimes.keys
			{
				if var sample = blockTimes[key]
				{
					sample.lastMS = 0
					blockTimes[key] = sample
				}
			}
		}
	}

	/// Returns the stat for a given name
	public class func getStat(name: String) -> Sample?
	{
		return blockTimes[name]
	}

	/// Prints the current set of stats for the PerfTimer session. If the PerfTimer hasn't already been stopped, it is stopped
	/// before the stats have been printed.
	public class func statsString() -> String
	{
		var result = ""

		// If we're not stopped, calculate the measured time
		let measuredTimeMS = self.measuredTimeMS != 0 ? self.measuredTimeMS : PausableTime.getTimeMS() - startTimeMS

		// Add up our total measured time
		var trackedTimeMS: Real = 0
		BlockTimesMutex.fastsync
		{
			for key in blockTimes.keys
			{
				trackedTimeMS += blockTimes[key]!.totalMS
			}

			result += "*** PERFORMANCE INFO ***\n"
			result += "\n"
			result += "    Total tracked time (via track)     : \(String(format: "%.2fms", arguments: [Float(trackedTimeMS)]))\n"
			result += "    Measured time                      : \(String(format: "%.2fms", arguments: [measuredTimeMS]))\n"
			if measuredTimeMS > 0 {
			result += "    % tracked of measured              : \(String(format: "%.2f", arguments: [Float(trackedTimeMS * 100 / Real(measuredTimeMS))]))%\n"
			result += "\n"
			}

			result += "    Tracked times:\n"

			// Find the max key length
			var maxKeyLength = 0
			for key in blockTimes.keys
			{
				maxKeyLength = max(key.length(), maxKeyLength)
			}

			for key in blockTimes.keys.sorted()
			{
				let bt = blockTimes[key]!

				let measuredPct = measuredTimeMS == 0 ? 0 : bt.totalMS * 100 / Real(measuredTimeMS)
				let totalPct = trackedTimeMS == 0 ? 0 : bt.totalMS * 100 / trackedTimeMS

				let keyStr = key.padding(toLength: maxKeyLength, withPad: " ", startingAt: 0)
				result += String(format: "      \(keyStr) : cnt[\(bt.count.toString(5))] total[%8.2fms] avg[%7.3fms] %%Measured[%7.3f%%] %%Total[%7.3f%%]\n",
					  arguments: [
						Float(bt.totalMS),
						Float(bt.averageMS),
						Float(measuredPct),
						Float(totalPct)])
			}
		}

		return result
	}
}
