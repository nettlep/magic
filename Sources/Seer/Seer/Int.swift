//
//  Int.swift
//  Seer
//
//  Created by Paul Nettle on 2/3/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Printing helper for binary values
// ---------------------------------------------------------------------------------------------------------------------------------

public extension Int
{
	/// Returns a value from the set [-1, 0, +1] representing the sign of the value
	@inline(__always) func sign() -> Int
	{
		// An efficient C++ implementation would look like this, due to the way it converts boolean results to 0/1. This uses
		// compares, but avoids branches (so it's very fast.) See http://stackoverflow.com/a/14612943/2203321.
		//
		//	return (self > 0) - (self < 0)
		return self < 0 ? -1 : (self > 0 ? 1 : 0)
	}

	/// Returns the number of leading bits with the same value (either 0 or 1).
	///
	/// Examples displayed in LSB->MSB order:
	///
	///     01000011 -> Two leading bits (both are 1s)
	///     11000000 -> Six leading bits (all are 0s)
	///
	/// This function will always return a number >= 1
	func countLeadingBits(maxBits: Int = MemoryLayout<Int>.size * 8) -> Int
	{
		assert(maxBits >= 0 && maxBits <= MemoryLayout<Int>.size * 8)
		let match = self & 1
		var count = 1
		for i in 1..<maxBits
		{
			if (self >> i) & 1 != match { break }
			count += 1
		}

		return count
	}

	// Returns the number of bits that are set
	//
	// IMPORTANT: This method only works for positive values
	func countSetBits() -> Int
	{
		var value = self
		var count = 0
		while value > 0
		{
			if (value & 1) == 1 { count += 1}
			value = value >> 1
		}
		return count
	}
}
