//
//  Random.swift
//  Minion
//
//  Created by Paul Nettle on 1/28/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

public class Random
{
	/// Singleton interface
	private static var singletonInstance: Random?
	public static var instance: Random
	{
		get
		{
			if singletonInstance == nil
			{
				singletonInstance = Random()
			}

			return singletonInstance!
		}
		set
		{
			assert(singletonInstance != nil)
		}
	}

	/// Initialize our random number generator
	///
	/// Made private to allow for a proper singleton
	private init()
	{
		#if os(Linux)
			srandom(UInt32(time(nil)))
		#endif
	}

	/// Returns a pseudo-random number R in the range [`lower` ≤ R < `upper`]
	///
	/// If an invalid range is provided (i.e. `upper` is not greater than `lower`) this method will return `nil`.
	///
	/// On Linux, if `upper` exceeds `RAND_MAX`, this method will return `nil`.
	public static func valueInRange(lower: UInt32 = 0, upper: UInt32) -> UInt32?
	{
		// On Linux, ensure we don't exceed RAND_MAX
		#if os(Linux)
			assert(upper <= UInt32(RAND_MAX))
			if upper > UInt32(RAND_MAX) { return nil }
		#endif

		// Ensure we have a valid range
		assert(lower < upper)
		if upper <= lower { return nil }

		#if os(Linux)
			return (value() % upper) + lower
		#else
			return arc4random_uniform(upper) + lower
		#endif
	}

	/// Returns a 32-bit random value
	///
	/// On Linux, note that the returned value will not exceed RAND_MAX
	public static func value() -> UInt32
	{
		#if os(Linux)
			return UInt32(random())
		#else
			return arc4random()
		#endif
	}

	/// Returns a random unit scalar in the range [`0` ≤ R < `1.0`]
	public static func scalar() -> Double
	{
		#if os(Linux)
			return Double(random()) / (Double(RAND_MAX)+1)
		#else
			return Double(arc4random()) / Double(4294967296.0)
		#endif
	}
}
