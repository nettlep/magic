//
//  Numeric.swift
//  Seer
//
//  Created by Paul Nettle on 3/31/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

// ---------------------------------------------------------------------------------------------------------------------------------
// Numeric types
// ---------------------------------------------------------------------------------------------------------------------------------

/// Our real number type
public typealias Real = Float

// ---------------------------------------------------------------------------------------------------------------------------------
// Range clamping
// ---------------------------------------------------------------------------------------------------------------------------------

/// Clamp: "combining min & max since 1026"
@inline(__always) public func clamp<T: Comparable>(_ x: T, _ min: T, _ max: T) -> T
{
	return Swift.min(max, Swift.max(min, x))
}
