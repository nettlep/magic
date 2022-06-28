//
//  PausableTime.swift
//  Seer
//
//  Created by Paul Nettle on 12/31/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// A high-precision value that represents time in milliseconds
public typealias Time = TimeInterval

/// A system time that can be paused
public final class PausableTime
{
	/// Stores the total paused time (stored as milliseconds)
	private static var totalPausedTimeMS: Time = 0

	/// Start of the most recent pause, so we can keep track of total time that we were paused (stored as milliseconds)
	private static var pausedStartTimeMS: Time?

	/// Returns the total accumulated paused time, in milliseconds
	public class func getTotalPausedTimeMS() -> Time
	{
		return totalPausedTimeMS
	}

	/// Returns true if we are paused, false otherwise
	public class func isPaused() -> Bool
	{
		return pausedStartTimeMS != nil
	}

	/// Pauses time by keeping track of total time that is paused
	///
	/// Calling this method if we are already paused does nothing
	public class func pause()
	{
		// If we're already paused, ignore this request
		if pausedStartTimeMS != nil { return }

		// Get the current start time of the pause
		pausedStartTimeMS = getTimeActualMS()
	}

	/// Un-pauses time, keeping track of total paused time
	///
	/// Calling this method if we not are already paused does nothing
	public class func unpause()
	{
		// Track our total paused time
		if let pausedStartTimeMS = pausedStartTimeMS
		{
			// Accumulate total paused time
			totalPausedTimeMS += getTimeActualMS() - pausedStartTimeMS

			// Reset the paused start time (this makes us no longer paused)
			self.pausedStartTimeMS = nil
		}
	}

	/// Returns the current system absolute time, ignoring pause history
	///
	/// Absolute time is measured in milliseconds relative to the absolute reference date of Jan 1 2001 00:00:00 GMT. See
	/// CFAbsoluteTimeGetCurrent() for details.
	public class func getTimeActualMS() -> Time
	{
		return Date.timeIntervalSinceReferenceDate * 1000.0
	}

	/// Returns the current system absolute time, taking pauses into consideration
	///
	/// Absolute time is measured in milliseconds relative to the absolute reference date of Jan 1 2001 00:00:00 GMT. See
	/// CFAbsoluteTimeGetCurrent() for details.
	public class func getTimeMS() -> Time
	{
		let now = getTimeActualMS()
		var curTime = now - totalPausedTimeMS

		// If we're currently paused, include that as well
		if let pausedStartTime = pausedStartTimeMS
		{
			curTime -= now - pausedStartTime
		}

		return curTime
	}
}
