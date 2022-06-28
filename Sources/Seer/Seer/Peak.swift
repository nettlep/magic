//
//  Peak.swift
//  Seer
//
//  Created by Paul Nettle on 2/26/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// Representation of a peak value within a stream of data
///
/// The peak is considered the value with the greatest distance from zero. Each peak stores the peak value itself, along with the
/// offset within the data.
struct Peak
{
	/// The peak slope value
	///
	/// Note that these are scaled by the window size (we use rolling sums rather than rolling averages)
	var scaledPeakSlope: RollValue

	/// The sample offset where the peak was found
	var sampleOffset: Int

	/// The min/max value that was used when thresholding this peak value
	var minMax: MinMax<Sample>

	/// The threshold that was used to detect this peak
	var threshold: RollValue

	/// Initialize a peak from the essentials
	init(scaledPeakSlope: RollValue, sampleOffset: Int, minMax: MinMax<Sample> = MinMax<Sample>(min: 0, max: 0), threshold: RollValue = 0)
	{
		self.scaledPeakSlope = scaledPeakSlope
		self.sampleOffset = sampleOffset
		self.minMax = minMax
		self.threshold = threshold
	}
}

extension Peak: Comparable
{
	public static func == (lhs: Peak, rhs: Peak) -> Bool
	{
		return lhs.scaledPeakSlope == rhs.scaledPeakSlope
	}

	public static func < (lhs: Peak, rhs: Peak) -> Bool
	{
		return lhs.scaledPeakSlope < rhs.scaledPeakSlope
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension Peak: CustomStringConvertible, CustomDebugStringConvertible
{
	var debugDescription: String
	{
		return description
	}

	var description: String
	{
		return "(slope[\(scaledPeakSlope)] off[\(sampleOffset)] mm[\(minMax)] thr:[\(threshold)])"
	}
}
