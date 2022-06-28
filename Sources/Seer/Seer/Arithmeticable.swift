//
//  Math.swift
//  Seer
//
//  Created by Paul Nettle on 12/28/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

// ---------------------------------------------------------------------------------------------------------------------------------
// Arithmeticable - a protocol with support for basic arithmetic operations
// ---------------------------------------------------------------------------------------------------------------------------------

/// Basic protocol that specifies a type supports arithmetic operations
///
/// Operations: +, -, *, /
public protocol Arithmeticable: ExpressibleByIntegerLiteral
{
	static func + (lhs: Self, rhs: Self) -> Self
	static func += (lhs: inout Self, rhs: Self)

	static func - (lhs: Self, rhs: Self) -> Self
	static func -= (lhs: inout Self, rhs: Self)

	static func * (lhs: Self, rhs: Self) -> Self
	static func *= (lhs: inout Self, rhs: Self)

	static func / (lhs: Self, rhs: Self) -> Self
	static func /= (lhs: inout Self, rhs: Self)
}

/// Declare that Int supports Arithmeticable
extension Int: Arithmeticable {}

/// Declare that Int8 supports Arithmeticable
extension Int8: Arithmeticable {}

/// Declare that Int32 supports Arithmeticable
extension Int32: Arithmeticable {}

/// Declare that Int64 supports Arithmeticable
extension Int64: Arithmeticable {}

/// Declare that UInt supports Arithmeticable
extension UInt: Arithmeticable {}

/// Declare that UInt8 supports Arithmeticable
extension UInt8: Arithmeticable {}

/// Declare that UInt32 supports Arithmeticable
extension UInt32: Arithmeticable {}

/// Declare that UInt64 supports Arithmeticable
extension UInt64: Arithmeticable {}

/// Declare that Float supports Arithmeticable
extension Float: Arithmeticable {}

/// Declare that Double supports Arithmeticable
extension Double: Arithmeticable {}
