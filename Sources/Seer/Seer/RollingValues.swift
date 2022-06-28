//
//  RollingValues.swift
//  Seer
//
//  Created by Paul Nettle on 12/17/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

// ---------------------------------------------------------------------------------------------------------------------------------
// Custom types
// ---------------------------------------------------------------------------------------------------------------------------------

/// The type used for rolling values... this must be a signed type
public typealias RollValue = Int32

// -----------------------------------------------------------------------------------------------------------------------------
// Local constants
// -----------------------------------------------------------------------------------------------------------------------------

/// The rate at which the `data` array grows to meet the needs of a new allocation
///
/// IMPORTANT: This value must always be >= 1.0
private let kCapacityGrowthScalar = FixedPoint(1.5)

/// Extension to the UnsafeMutableArray which provides functionality for rolling values
///
/// Each method will be limited to a specific type of data. See each method for specifics on the types they will work with.
extension UnsafeMutableArray where Element == RollValue
{
	/// Generates a rolling sum with a window size of `windowSize` from the input `samples` (with a length of `count`)
	///
	/// At the end of this call, `data` will contain rolling sums.
	///
	/// If the `windowSize` is larger than `count`, then there isn't enough data to provide a single average of the requested
	/// `windowSize`. In that case, this function will return false. Otherwise, it will return true.
	public mutating func rollSums(samples: UnsafeMutableArray<Sample>, windowSize: Int) -> Bool
	{
		// The index of the last value we can store
		let last = samples.count - windowSize
		if last < 0 { return false }

		// Clear out the data and make sure we have enough room
		ensureReservation(capacity: last + 1, growthScalar: kCapacityGrowthScalar)
		self.count = last + 1

		// Lead-in - sum the initial window values
		var sum: RollValue = 0
		for i in 0..<windowSize
		{
			sum += RollValue(samples[i])
		}

		// Store the value and roll forward (in that order)
		for i in 0..<last
		{
			_rawPointer[i] = sum
			sum -= RollValue(samples[i])
			sum += RollValue(samples[i+windowSize])
		}

		// Store the final rolled value
		_rawPointer[last] = sum
		return true
	}

	/// Generates a rolling average with a window size of `windowSize` from the input `samples` (with a length of `count`)
	///
	/// At the end of this call, `data` will contain rolling averages.
	///
	/// If the `windowSize` is larger than `count`, then there isn't enough data to provide a single average of the requested
	/// `windowSize`. In that case, this function will return false. Otherwise, it will return true.
	public mutating func rollAverages(samples: UnsafeMutableArray<Sample>, windowSize: Int) -> Bool
	{
		// The index of the last value we can store
		let last = samples.count - windowSize
		if last < 0 { return false }

		// Clear out the data and make sure we have enough room
		ensureReservation(capacity: last + 1, growthScalar: kCapacityGrowthScalar)
		self.count = last + 1

		// Instead of a divide, we'll multiply by 1/windowSize
		let oneOverCount = FixedPoint.kOne / windowSize

		// Lead-in - sum the initial window values
		var sum: RollValue = 0
		for i in 0..<windowSize
		{
			sum += RollValue(samples[i])
		}

		// Store the value and roll forward (in that order)
		for i in 0..<last
		{
			_rawPointer[i] = RollValue((oneOverCount * sum).floor())
			sum -= RollValue(samples[i])
			sum += RollValue(samples[i+windowSize])
		}

		// Store the final rolled value
		_rawPointer[last] = RollValue((oneOverCount * sum).floor())
		return true
	}
}
