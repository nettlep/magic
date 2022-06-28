//
//  MinMax.swift
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

// -----------------------------------------------------------------------------------------------------------------------------
// Local constants
// -----------------------------------------------------------------------------------------------------------------------------

/// The rate at which the `data` array grows to meet the needs of a new allocation
///
/// IMPORTANT: This value must always be >= 1.0
private let kCapacityGrowthScalar = FixedPoint(1.5)

/// A structure that holds a min/max and can update with new min/max values
public struct MinMax<T: Comparable>
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The minimum and maximum values
	public var min, max: T

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a MinMax with the base components
	public init(min: T, max: T)
	{
		self.min = min
		self.max = max
	}

	/// Initialize a MinMax with a single value for both `min` and `max`
	public init(with value: T)
	{
		min = value
		max = value
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Update the stored `min` & `max` with the given `value`
	///
	/// `min` is only updated if `value` is less.
	/// `max` is only updated if `value` is greater.
	@inline(__always) public mutating func update(with value: T)
	{
		if      value < min { min = value }
		else if max < value { max = value }
	}

	/// Update the stored `min` & `max` with the given `value`
	///
	/// `min` is only updated if `minMax.min` is less.
	/// `max` is only updated if `minMax.max` is greater.
	@inline(__always) public mutating func update(with minMax: MinMax<T>)
	{
		if minMax.min < min { min = minMax.min }
		if max < minMax.max { max = minMax.max }
	}

	/// Update the stored `min` & `max` with the given `value`
	///
	/// `min` is only updated if `newMin` is less.
	/// `max` is only updated if `newMax` is greater.
	@inline(__always) mutating func update(min newMin: T, max newMax: T)
	{
		if newMin < min { min = newMin }
		if max < newMax { max = newMax }
	}
}

extension MinMax: Comparable
{
	public static func == (lhs: MinMax, rhs: MinMax) -> Bool
	{
		return lhs.min == rhs.min && lhs.max == rhs.max
	}

	public static func < (lhs: MinMax, rhs: MinMax) -> Bool
	{
		return lhs.max < rhs.min
	}
}

extension MinMax where T: Arithmeticable
{
	/// Returns the difference between the min & max
	@inline(__always) public func range() -> T
	{
		return max - min
	}
}

extension MinMax where T: ExpressibleByIntegerLiteral
{
	/// Returns the difference between the min & max
	public init(min: T, max: T)
	{
		self.min = min
		self.max = max
	}
}

/// Extension to the UnsafeMutableArray which provides functionality for calculating MinMax values
///
/// Each method will be limited to a specific type of data. See each method for specifics on the types they will work with.
extension UnsafeMutableArray where Element: Comparable & ExpressibleByIntegerLiteral
{
	/// Calculates the min & max for the full array
	///
	/// If the array contains no values, this method will return MinMax(min: 0, max: 0).
	///
	/// To calculate min/max for a subset of the array, use `getMinMax(range:)` or `getMinMax(start:count:)`
	public func getMinMax() -> MinMax<Element>
	{
		if count <= 0
		{
			return MinMax(min: 0, max: 0)
		}

		var minMax = MinMax<Element>(with: self[0])
		for i in 1..<count
		{
			minMax.update(with: self[i])
		}
		return minMax
	}

	/// Calculates the min & max for a subset of samples (defined by `start` and `count`) in the array
	///
	/// The start/count are clipped to the array's set of valid elements. If the specified range does not intersect the array's set
	/// of valid elements, this method will return MinMax(min: 0, max: 0).
	///
	/// To calculate min/max for the entire array, use `getMinMax()`
	public func getMinMax(start inStart: Int, count inCount: Int) -> MinMax<Element>
	{
		assert(count > 0)

		// Early out for obviously invalid lines
		if inStart >= count || inCount <= 0
		{
			return MinMax(min: 0, max: 0)
		}

		// Clip
		var start = inStart
		var end = inStart + inCount
		if start < 0
		{
			end += start
			start = 0
		}

		if end <= 0
		{
			return MinMax(min: 0, max: 0)
		}
		else if end > count
		{
			end = count
		}

		// Go grab that min/max
		var minMax = MinMax<Element>(with: self[start])
		start += 1
		while start < end
		{
			minMax.update(with: self[start])
			start += 1
		}

		return minMax
	}
}

/// Extension to the UnsafeMutableArray which provides functionality for rolling MinMax values
///
/// Each method will be limited to a specific type of data. See each method for specifics on the types they will work with.
extension UnsafeMutableArray where Element == MinMax<Sample>
{
	/// Generates a rolling MinMax with a window size of `windowSize` from the input `samples` (with a length of `count`)
	///
	/// At the end of this call, `data` will contain a set of rolled MinMax structures.
	///
	/// This method is specialized to roll a mutable pointer of Sample values into an array of type MinMax<RollValue>.
	///
	/// If the `windowSize` is larger than `count`, then there isn't enough data to provide a single MinMax of the requested
	/// `windowSize`. In that case, this function will return false. Otherwise, it will return true.
	public mutating func rollMinMax(samples: UnsafeMutableArray<Sample>, count inCount: Int, windowSize inWindowSize: Int) -> Bool
	{
		// Ensure we have sane input
		if samples.count <= 0 { return false }

		// Clamp the windowSize to count
		let windowSize = min(inWindowSize, samples.count)

		// Clear out the data and ensure we have enough room
		ensureReservation(capacity: samples.count, growthScalar: kCapacityGrowthScalar)

		// Prime our rolling min/max with the first full window
		var minMax = MinMax(with: samples[0])
		for i in 0..<windowSize
		{
			minMax.update(with: samples[i])
		}

		// Roll the min/max
		//
		// We loop through of the center samples of our rolling min/max, except the last one. We do this because the code
		// in this loop ends with a rolling forward of the min/max. This min/max is then used in the following loop to
		// write the last full rolling min/max value, and then continues to fill out the last halfWindowSize values.
		let end = inCount - windowSize
		var i = 0
		while i < end
		{
			// Store the current min/max
			add(minMax)

			// Roll forward
			let rollOutValue = samples[i]
			let rollInValue = samples[i + windowSize]

			// If we roll in a new min, we can skip the rolling process
			if rollInValue <= minMax.min
			{
				minMax.min = rollInValue
			}
			// If our min must rolled out, re-calc
			else if rollOutValue == minMax.min
			{
				minMax.min = rollInValue
				let end = i + windowSize
				for j in i+1..<end
				{
					let sample = samples[j]
					if sample < minMax.min { minMax.min = sample }
				}
			}

			// If we roll in a new max, we can skip the rolling process
			if rollInValue >= minMax.max
			{
				minMax.max = rollInValue
			}
			// If our max must rolled out, re-calc
			else if rollOutValue == minMax.max
			{
				minMax.max = rollInValue
				let end = i + windowSize
				for j in i+1..<end
				{
					let sample = samples[j]
					if minMax.max < sample { minMax.max = sample }
				}
			}

			i += 1
		}

		// Populate the last full averaged sample, and then our lead-out samples
		for _ in end..<inCount
		{
			add(minMax)
		}

		return true
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension MinMax: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		return "\(min),\(max)"
	}
}
