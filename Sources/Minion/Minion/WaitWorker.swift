//
//  WaitWorker.swift
//  Minion
//
//  Created by Paul Nettle on 2/23/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// A WaitWorker provides a way to perform a task with a higher granularity to the waiting operation.
///
/// A typical use case would be to wait on a background task to set a flag with a 60 second timeout. This would be accomplished by
/// the following example:
///
///     bool success = WaitWorker.execFor(60000, intervalMS: 10)
///     {
///         // Return `true` if our worker has finished its work, otherwise we return `false` to keep waiting
///         return backgroundWorker.isFinished()
///     }
///
///     if !success
///     {
///         print("The operation timed out waiting for isDone to become true")
///     }
///
/// In the example above, we are waiting for `backgroundWorker` to report it is finished, with a timeout of 60 seconds. The
/// `WaitWorker` will call the block every 10 milliseconds (the `intervalMS` parameter) until it returns `true` or until the total
/// time elapsed reaches 60 seconds.
public struct WaitWorker
{
	/// We sleep for periods of time this long until the total time is elapsed
	public static let kDefaultSleepIntervalMS: Int = 10

	/// Repeatedly executes `operation` until it completes or up to `timeoutMS` milliseconds, sleeping for `intervalMS`
	/// milliseconds between each execution
	///
	/// `operation` should return `true` if it has completed its task. Otherwise, `operation` will be called again after
	/// `intervalMS` millisecond sleep.
	///
	/// If `intervalMS` is not specified, it defaults to `WaitWorker.kSleepIntervalMS`. If `intervalMS` is <= 0, there will be no
	/// sleep between executions of `operation`.
	///
	/// If `timeoutMS` is <= 0, this method returns `false` immediately without calling `operation`.
	///
	/// The total time of execution could theoretically be as long as the total `timeoutMS` time plus the execution time of
	/// `operation`.
	///
	/// The precision of timing in this method is dependent upon the execution time of `operation` as well as `Thread.sleep`.
	///
	/// Returns `true` if the operation completed before `timeoutMS`, otherwise `false`
	public static func execFor(_ timeoutMS: Int, intervalMS: Int = kDefaultSleepIntervalMS, _ operation: () -> Bool) -> Bool
	{
		// If we don't have an execution time, just return false
		if timeoutMS <= 0 { return false}

		// Our end time
		let endTime = Date.timeIntervalSinceReferenceDate + Double(timeoutMS) / 1000.0

		// Our interval time in `TimeInterval` seconds
		let intervalSec = TimeInterval(intervalMS) / 1000

		while true
		{
			// Execute the operation
			if operation() { return true }

			// Timed out?
			let now = Date.timeIntervalSinceReferenceDate
			if now > endTime { return false }

			// How long to nap for?
			let intervalTimeSec = min(now + intervalSec, endTime) - now

			// Nap
			if intervalTimeSec > 0 { Thread.sleep(forTimeInterval: intervalTimeSec) }
		}
	}

	/// Repeatedly executes `operation` until it completes, sleeping for `intervalMS` milliseconds between each execution
	///
	/// `operation` should return `true` if it has completed its task. Otherwise, `operation` will be called again after
	/// `intervalMS` millisecond sleep.
	///
	/// If `intervalMS` is <= 0, there will be no sleep between executions of `operation`.
	///
	/// The precision of timing in this method is dependent upon the execution time of `operation` as well as `Thread.sleep`.
	public static func execEvery(_ intervalMS: Int, _ operation: () -> Bool)
	{
		// Convert our values into `TimeInterval` seconds
		let intervalSec = TimeInterval(intervalMS) / 1000

		while true
		{
			// Execute the operation
			if operation() { return }

			// Should we sleep for a bit?
			if intervalSec > 0 { Thread.sleep(forTimeInterval: intervalSec) }
		}
	}
}
