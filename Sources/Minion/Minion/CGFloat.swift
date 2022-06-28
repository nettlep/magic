//
//  CGFloat.swift
//  Minion
//
//  Created by Paul Nettle on 3/2/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: CGFloat -> Integer support
// ---------------------------------------------------------------------------------------------------------------------------------

#if !os(iOS)
extension CGFloat
{
	/// Returns the nearest integer value
	@inline(__always) public func roundToNearest() -> Int
	{
		return Int(self < 0.0 ? self - 0.5 : self + 0.5)
	}

	/// Returns the nearest integer toward zero
	@inline(__always) public func roundTowardZero() -> Int
	{
		return Int(self)
	}

	/// Returns the nearest integer away from zero
	@inline(__always) public func roundAwayFromZero() -> Int
	{
		return self > 0 ? Int(ceil()) : Int(floor())
	}

	/// Returns integer value toward negative infinity
	@inline(__always) public func floor() -> Int
	{
		#if os(Linux)
			return Int(Glibc.floor(self))
		#else
			return Int(Darwin.floor(self))
		#endif
	}

	/// Returns integer value toward positive infinity
	@inline(__always) public func ceil() -> Int
	{
		#if os(Linux)
			return Int(Glibc.ceil(self))
		#else
			return Int(Darwin.ceil(self))
		#endif
	}
}
#endif
