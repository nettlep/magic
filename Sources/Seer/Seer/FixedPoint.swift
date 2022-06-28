//
//  FixedPoint.swift
//  Seer
//
//  Created by Paul Nettle on 11/13/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
#if os(iOS)
import MinionIOS
import UIKit
#else
import Minion
#endif

/// A type that can be initialized with a floating-point literal.
public protocol ExpressibleByFixedPointLiteral
{
	/// Creates an instance initialized to the specified FixedPoint value.
	init(fixedPointLiteral value: FixedPoint)
}

/// Protocol for values that can be converted to a FixedPoint type
public protocol ConvertibleToFixedPoint
{
	/// Returns a FixedPoint value
	func toFixed() -> FixedPoint
}

/// A fixed point value
///
/// The total size is determined by FixedType and the number of fractional bits is determined by kFractionalBits
public struct FixedPoint
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The number of fractional bits within the FixedPoint value
	///
	/// Note that although this is a standard integer value, it is stored as a FixedType in order to work with FixedType values
	///
	/// If you change FixedType, be sure to reconsider what kFractionalBits should be!
	public static let kFractionalBits = FixedType(16)

	/// A bit mask representing the fractional bits of the internal FixedType value
	public static let kFractionalMask = FixedType((1 << (kFractionalBits-1)) - 1)

	/// A constant FixedPoint value of 0.0
	public static let kZero = FixedPoint(withRaw: 0)

	/// A constant FixedPoint value of 1.0
	public static let kOne = FixedPoint(withRaw: 1 << FixedPoint.kFractionalBits)

	/// A constant FixedPoint value of 0.5
	public static let kHalf = FixedPoint(withRaw: kOne.value >> 1)

	/// A constant FixedPoint value of 0.25
	public static let kQuarter = FixedPoint(withRaw: kHalf.value >> 1)

	// -----------------------------------------------------------------------------------------------------------------------------
	// Internal types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Internal type used for the fixed point
	///
	/// If you change FixedType, be sure to reconsider what kFractionalBits should be!
	public typealias FixedType = Int32

	/// Used by Strideable to allow fixed point values to be iterated using stride
	public typealias Stride = FixedPoint

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The internal value for this fixed point value
	public var value: FixedType

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize with a FixedType value
	///
	/// As the input is a FixedType it is assumed to be in fixed point format so we simply copy it
	@inline(__always) public init(withRaw rawValue: FixedType)
	{
		self.value = rawValue
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Convenience initializers for conversion from common types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a FixedPoint value (sets it to zero)
	@inline(__always) public init()
	{
		self.init(withRaw: 0)
	}

	/// Convenience initialize with a convertible type
	@inline(__always) public init(_ convertibleValue: ConvertibleToFixedPoint)
	{
		self.init(withRaw: convertibleValue.toFixed().value)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Conversion
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The value as a CGFloat
	@inline(__always) public func toCGFloat() -> CGFloat
	{
		return CGFloat(value) / CGFloat(1 << FixedPoint.kFractionalBits)
	}

	/// The value as a Float
	@inline(__always) public func toFloat() -> Float
	{
		return Float(value) / Float(1 << FixedPoint.kFractionalBits)
	}

	/// The value as a Double
	@inline(__always) public func toDouble() -> Double
	{
		return Double(value) / Double(1 << FixedPoint.kFractionalBits)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Rounding
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the nearest integer value
	@inline(__always) public func roundToNearest() -> Int
	{
		let half = (1 << (FixedPoint.kFractionalBits-1))
		return Int((value<0 ? value-FixedType(half) : value+FixedType(half)) >> FixedPoint.kFractionalBits)
	}

	/// Returns the nearest integer value closest to zero
	///
	/// Note that this requires a sign check. If you know the sign of your numbers, you can use floor() instead. For positive
	/// values, just call floor(). For negative numbers, negate the value first, then call floor, then negate the result.
	@inline(__always) public func roundTowardZero() -> Int
	{
		return value < 0 ? -Int(-value >> FixedPoint.kFractionalBits) : Int(value >> FixedPoint.kFractionalBits)
	}

	/// Returns the nearest integer value farthest from zero
	@inline(__always) public func roundAwayFromZero() -> Int
	{
		return value > 0 ? ceil() : floor()
	}

	/// Returns integer value toward negative infinity
	@inline(__always) public func floor() -> Int
	{
		return Int(value >> FixedPoint.kFractionalBits)
	}

	/// Returns integer value toward positive infinity
	@inline(__always) public func ceil() -> Int
	{
		return -Int(-value >> FixedPoint.kFractionalBits)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Sign
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns a value from the set [-1, 0, +1] representing the sign of the value
	@inline(__always) public func sign() -> Int
	{
		// An efficient C++ implementation would look like this, due to the way it converts boolean results to 0/1. This uses
		// compares, but avoids branches (so it's very fast.) See http://stackoverflow.com/a/14612943/2203321.
		//
		//	return (value > 0) - (value < 0)
		return value < 0 ? -1 : (value > 0 ? 1 : 0)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Shifting
	// -----------------------------------------------------------------------------------------------------------------------------

	@inline(__always) public static func << (left: FixedPoint, right: Int) -> FixedPoint
	{
		return FixedPoint(withRaw: left.value << FixedType(right))
	}

	@inline(__always) public static func <<= (left: inout FixedPoint, right: Int)
	{
		left = left << right
	}

	@inline(__always) public static func >> (left: FixedPoint, right: Int) -> FixedPoint
	{
		return FixedPoint(withRaw: left.value >> FixedType(right))
	}

	@inline(__always) public static func >>= (left: inout FixedPoint, right: Int)
	{
		left = left >> right
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Misc math functions
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Scales self to the range of [0, 1] within the range of [start, end].
	///
	/// if self == start, then the result is 0.0
	/// if self == end, then the result is 1.0
	/// if self < start then the result is < 0.0
	/// if self > end then the result is > 1.0
	@inline(__always) public func unitScalar(from start: FixedPoint, to end: FixedPoint) -> FixedPoint
	{
		return (self - start) / (end - start)
	}

	/// Scales self to the range of [0, 1] within the range of [0, end].
	///
	/// if self == 0, then the result is 0.0
	/// if self == end, then the result is 1.0
	/// if self < 0 then the result is < 0.0
	/// if self > end then the result is > 1.0
	@inline(__always) public func unitScalar(to end: FixedPoint) -> FixedPoint
	{
		return self / end
	}

	/// Scales self to the range of [0, 1] within the range of [start, end].
	///
	/// if self == start, then the result is 0.0
	/// if self == end, then the result is 1.0
	/// if self < start then the result is < 0.0
	/// if self > end then the result is > 1.0
	@inline(__always) public func unitScalar(from start: Int, to end: Int) -> FixedPoint
	{
		return (self - FixedPoint(start)) / FixedPoint(end - start)
	}

	/// Scales self to the range of [0, 1] within the range of [0, end].
	///
	/// if self == 0, then the result is 0.0
	/// if self == end, then the result is 1.0
	/// if self < 0 then the result is < 0.0
	/// if self > end then the result is > 1.0
	@inline(__always) public func unitScalar(to end: Int) -> FixedPoint
	{
		return self / FixedPoint(end)
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: SignedNumeric (+ Numeric)
// ---------------------------------------------------------------------------------------------------------------------------------

extension FixedPoint: SignedNumeric { }

extension FixedPoint
{
	public typealias Magnitude = FixedPoint

	public init?<T>(exactly: T) where T: BinaryInteger
	{
		self.value = FixedPoint.FixedType(exactly) << FixedPoint.kFractionalBits
	}

	public var magnitude: Magnitude
	{
		return value >= 0 ? self : FixedPoint(-value)
	}

	@inline(__always) mutating public func negate()
	{
		value = -value
	}

	@inline(__always) public static prefix func - (x: FixedPoint) -> FixedPoint
	{
		return FixedPoint(withRaw: -x.value)
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Equatable (+ Comparable)
// ---------------------------------------------------------------------------------------------------------------------------------

extension FixedPoint: Equatable
{
	@inline(__always) public static func == (left: FixedPoint, right: FixedPoint) -> Bool
	{
		return left.value == right.value
	}

	@inline(__always) public static func == (left: FixedPoint, right: ConvertibleToFixedPoint) -> Bool
	{
		return left == right.toFixed()
	}

	@inline(__always) public static func != (left: FixedPoint, right: FixedPoint) -> Bool
	{
		return !(left == right)
	}

	@inline(__always) public static func != (left: FixedPoint, right: ConvertibleToFixedPoint) -> Bool
	{
		return !(left == right)
	}
	@inline(__always) public static func < (left: FixedPoint, right: FixedPoint) -> Bool
	{
		return left.value < right.value
	}

	@inline(__always) public static func < (left: FixedPoint, right: ConvertibleToFixedPoint) -> Bool
	{
		return left < right.toFixed()
	}

	@inline(__always) public static func <= (left: FixedPoint, right: FixedPoint) -> Bool
	{
		return left.value <= right.value
	}

	@inline(__always) public static func <= (left: FixedPoint, right: ConvertibleToFixedPoint) -> Bool
	{
		return left <= right.toFixed()
	}

	@inline(__always) public static func > (left: FixedPoint, right: FixedPoint) -> Bool
	{
		return left.value > right.value
	}

	@inline(__always) public static func > (left: FixedPoint, right: ConvertibleToFixedPoint) -> Bool
	{
		return left > right.toFixed()
	}

	@inline(__always) public static func >= (left: FixedPoint, right: FixedPoint) -> Bool
	{
		return left.value >= right.value
	}

	@inline(__always) public static func >= (left: FixedPoint, right: ConvertibleToFixedPoint) -> Bool
	{
		return left >= right.toFixed()
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Arithmeticable
// ---------------------------------------------------------------------------------------------------------------------------------

extension FixedPoint: Arithmeticable
{
	@inline(__always) public static func + (left: FixedPoint, right: FixedPoint) -> FixedPoint
	{
		var result = left
		result += right
		return result
	}

	@inline(__always) public static func + (left: FixedPoint, right: ConvertibleToFixedPoint) -> FixedPoint
	{
		var result = right.toFixed()
		result += left
		return result
	}

	@inline(__always) public static func += (left: inout FixedPoint, right: ConvertibleToFixedPoint)
	{
		left += right.toFixed()
	}

	@inline(__always) public static func += (left: inout FixedPoint, right: FixedPoint)
	{
		left.value += right.value
	}

	@inline(__always) public static func - (left: FixedPoint, right: FixedPoint) -> FixedPoint
	{
		var result = left
		result -= right
		return result
	}

	@inline(__always) public static func - (left: FixedPoint, right: ConvertibleToFixedPoint) -> FixedPoint
	{
		var result = left
		result -= right.toFixed()
		return result
	}

	@inline(__always) public static func -= (left: inout FixedPoint, right: ConvertibleToFixedPoint)
	{
		left -= right.toFixed()
	}

	@inline(__always) public static func -= (left: inout FixedPoint, right: FixedPoint)
	{
		left.value -= right.value
	}

	@inline(__always) public static func * (left: FixedPoint, right: FixedPoint) -> FixedPoint
	{
		var result = left
		result *= right
		return result
	}

	@inline(__always) public static func * (left: FixedPoint, right: ConvertibleToFixedPoint) -> FixedPoint
	{
		var result = right.toFixed()
		result *= left
		return result
	}

	@inline(__always) public static func *= (left: inout FixedPoint, right: ConvertibleToFixedPoint)
	{
		left *= right.toFixed()
	}

	@inline(__always) public static func *= (left: inout FixedPoint, right: FixedPoint)
	{
		//left = (left.toDouble() * right.toDouble()).toFixed()
		left.value = FixedType((Int64(left.value) &* Int64(right.value)) >> Int64(kFractionalBits))
	}

	@inline(__always) public static func / (left: FixedPoint, right: FixedPoint) -> FixedPoint
	{
		var result = left
		result /= right
		return result
	}

	@inline(__always) public static func / (left: FixedPoint, right: ConvertibleToFixedPoint) -> FixedPoint
	{
		var result = left
		result /= right.toFixed()
		return result
	}

	@inline(__always) public static func /= (left: inout FixedPoint, right: ConvertibleToFixedPoint)
	{
		left /= right.toFixed()
	}

	@inline(__always) public static func /= (left: inout FixedPoint, right: FixedPoint)
	{
		//left = (left.toDouble() / right.toDouble()).toFixed()
		left.value = FixedType((Int64(left.value) << Int64(kFractionalBits)) / Int64(right.value))
	}

	/// This is a specialized version of the multiply operator in that it doesn't need to convert the right-hand side to a
	/// fixed point. Only division and multiplication with an integer have this advantage.
	@inline(__always) public static func * (left: FixedPoint, right: Int) -> FixedPoint
	{
		var result = left
		result *= right
		return result
	}

	/// This is a specialized version of the multiply operator in that it doesn't need to convert the right-hand side to a
	/// fixed point. Only division and multiplication with an integer have this advantage.
	@inline(__always) public static func *= (left: inout FixedPoint, right: Int)
	{
		left.value *= FixedType(right)
	}

	/// This is a specialized version of the division operator in that it doesn't need to convert the right-hand side to a
	/// fixed point. Only division and multiplication with an integer have this advantage.
	@inline(__always) public static func / (left: FixedPoint, right: Int) -> FixedPoint
	{
		var result = left
		result /= right
		return result
	}

	/// This is a specialized version of the division operator in that it doesn't need to convert the right-hand side to a
	/// fixed point. Only division and multiplication with an integer have this advantage.
	@inline(__always) public static func /= (left: inout FixedPoint, right: Int)
	{
		left.value /= FixedType(right)
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension FixedPoint: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		return String(format: "%d.%04x", arguments: [value>>FixedPoint.kFractionalBits, value & FixedPoint.kFractionalMask])
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Conversions
// ---------------------------------------------------------------------------------------------------------------------------------

extension FixedPoint: ConvertibleToFixedPoint
{
	/// Returns the FixedPoint value as a FixedPoint (so the type itself conforms to its own ConvertibleToFixedPoint protocol)
	@inline(__always) public func toFixed() -> FixedPoint
	{
		return self
	}
}

extension FixedPoint: ExpressibleByIntegerLiteral
{
	@inline(__always) public init(integerLiteral: IntegerLiteralType)
	{
		self.init(withRaw: FixedType(integerLiteral) << FixedPoint.kFractionalBits)
	}
}

extension FixedPoint: ExpressibleByFloatLiteral
{
	@inline(__always) public init(floatLiteral: FloatLiteralType)
	{
		self.init(withRaw: FixedType(floatLiteral * FloatLiteralType(1 << FixedPoint.kFractionalBits)))
	}
}

extension FixedPoint: ExpressibleByFixedPointLiteral
{
	@inline(__always) public init(fixedPointLiteral value: FixedPoint)
	{
		self = value
	}
}

extension FixedPoint: Strideable
{
	@inline(__always) public func advanced(by n: FixedPoint.Stride) -> FixedPoint
	{
		return self + n
	}

	@inline(__always) public func distance(to other: FixedPoint) -> FixedPoint.Stride
	{
		return other - self
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Int <-> FixedPoint support
// ---------------------------------------------------------------------------------------------------------------------------------

extension Int { @inline(__always) init(_ value: FixedPoint) { self = value.floor() } }
extension UInt { @inline(__always) init(_ value: FixedPoint) { self = UInt(value.floor()) } }
extension Int8 { @inline(__always) init(_ value: FixedPoint) { self = Int8(value.floor()) } }
extension UInt8 { @inline(__always) init(_ value: FixedPoint) { self = UInt8(value.floor()) } }
extension Int16 { @inline(__always) init(_ value: FixedPoint) { self = Int16(value.floor()) } }
extension UInt16 { @inline(__always) init(_ value: FixedPoint) { self = UInt16(value.floor()) } }
extension Int32 { @inline(__always) init(_ value: FixedPoint) { self = Int32(value.floor()) } }
extension UInt32 { @inline(__always) init(_ value: FixedPoint) { self = UInt32(value.floor()) } }
extension Int64 { @inline(__always) init(_ value: FixedPoint) { self = Int64(value.floor()) } }
extension UInt64 { @inline(__always) init(_ value: FixedPoint) { self = UInt64(value.floor()) } }

extension Int: ConvertibleToFixedPoint { @inline(__always) public func toFixed() -> FixedPoint { return FixedPoint(withRaw: FixedPoint.FixedType(self) << FixedPoint.kFractionalBits) } }
extension UInt: ConvertibleToFixedPoint { @inline(__always) public func toFixed() -> FixedPoint { return FixedPoint(withRaw: FixedPoint.FixedType(self) << FixedPoint.kFractionalBits) } }
extension Int8: ConvertibleToFixedPoint { @inline(__always) public func toFixed() -> FixedPoint { return FixedPoint(withRaw: FixedPoint.FixedType(self) << FixedPoint.kFractionalBits) } }
extension UInt8: ConvertibleToFixedPoint { @inline(__always) public func toFixed() -> FixedPoint { return FixedPoint(withRaw: FixedPoint.FixedType(self) << FixedPoint.kFractionalBits) } }
extension Int16: ConvertibleToFixedPoint { @inline(__always) public func toFixed() -> FixedPoint { return FixedPoint(withRaw: FixedPoint.FixedType(self) << FixedPoint.kFractionalBits) } }
extension UInt16: ConvertibleToFixedPoint { @inline(__always) public func toFixed() -> FixedPoint { return FixedPoint(withRaw: FixedPoint.FixedType(self) << FixedPoint.kFractionalBits) } }
extension Int32: ConvertibleToFixedPoint { @inline(__always) public func toFixed() -> FixedPoint { return FixedPoint(withRaw: FixedPoint.FixedType(self) << FixedPoint.kFractionalBits) } }
extension UInt32: ConvertibleToFixedPoint { @inline(__always) public func toFixed() -> FixedPoint { return FixedPoint(withRaw: FixedPoint.FixedType(self) << FixedPoint.kFractionalBits) } }
extension Int64: ConvertibleToFixedPoint { @inline(__always) public func toFixed() -> FixedPoint { return FixedPoint(withRaw: FixedPoint.FixedType(self) << FixedPoint.kFractionalBits) } }
extension UInt64: ConvertibleToFixedPoint { @inline(__always) public func toFixed() -> FixedPoint { return FixedPoint(withRaw: FixedPoint.FixedType(self) << FixedPoint.kFractionalBits) } }

extension Int: ExpressibleByFixedPointLiteral { @inline(__always) public init(fixedPointLiteral value: FixedPoint) { self = value.floor() } }
extension UInt: ExpressibleByFixedPointLiteral { @inline(__always) public init(fixedPointLiteral value: FixedPoint) { self = UInt(value.floor()) } }
extension Int8: ExpressibleByFixedPointLiteral { @inline(__always) public init(fixedPointLiteral value: FixedPoint) { self = Int8(value.floor()) } }
extension UInt8: ExpressibleByFixedPointLiteral { @inline(__always) public init(fixedPointLiteral value: FixedPoint) { self = UInt8(value.floor()) } }
extension Int16: ExpressibleByFixedPointLiteral { @inline(__always) public init(fixedPointLiteral value: FixedPoint) { self = Int16(value.floor()) } }
extension UInt16: ExpressibleByFixedPointLiteral { @inline(__always) public init(fixedPointLiteral value: FixedPoint) { self = UInt16(value.floor()) } }
extension Int32: ExpressibleByFixedPointLiteral { @inline(__always) public init(fixedPointLiteral value: FixedPoint) { self = Int32(value.floor()) } }
extension UInt32: ExpressibleByFixedPointLiteral { @inline(__always) public init(fixedPointLiteral value: FixedPoint) { self = UInt32(value.floor()) } }
extension Int64: ExpressibleByFixedPointLiteral { @inline(__always) public init(fixedPointLiteral value: FixedPoint) { self = Int64(value.floor()) } }
extension UInt64: ExpressibleByFixedPointLiteral { @inline(__always) public init(fixedPointLiteral value: FixedPoint) { self = UInt64(value.floor()) } }

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: CGFloat <-> FixedPoint support
// ---------------------------------------------------------------------------------------------------------------------------------

extension CGFloat
{
	/// Initializes a CGFloat from a FixedPoint type
	@inline(__always) public init(_ fixedPoint: FixedPoint)
	{
		self = fixedPoint.toCGFloat()
	}
}

extension CGFloat: ConvertibleToFixedPoint
{
	/// Returns the CGFloat as a FixedPoint
	@inline(__always) public func toFixed() -> FixedPoint
	{
		return FixedPoint(withRaw: FixedPoint.FixedType(self * CGFloat(1 << FixedPoint.kFractionalBits)))
	}
}

extension CGFloat: ExpressibleByFixedPointLiteral
{
	/// Creates an instance initialized to the specified FixedPoint value.
	@inline(__always) public init(fixedPointLiteral value: FixedPoint)
	{
		self = value.toCGFloat()
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Float <-> FixedPoint support
// ---------------------------------------------------------------------------------------------------------------------------------

extension Float
{
	/// Initializes a Float from a FixedPoint type
	@inline(__always) public init(_ fixedPoint: FixedPoint)
	{
		self = fixedPoint.toFloat()
	}
}

extension Float: ConvertibleToFixedPoint
{
	/// Returns the Float as a FixedPoint
	@inline(__always) public func toFixed() -> FixedPoint
	{
		return FixedPoint(withRaw: FixedPoint.FixedType(self * Float(1 << FixedPoint.kFractionalBits)))
	}
}

extension Float: ExpressibleByFixedPointLiteral
{
	/// Creates an instance initialized to the specified FixedPoint value.
	@inline(__always) public init(fixedPointLiteral value: FixedPoint)
	{
		self = value.toFloat()
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Double <-> FixedPoint support
// ---------------------------------------------------------------------------------------------------------------------------------

extension Double
{
	/// Initializes a Double from a FixedPoint type
	@inline(__always) public init(_ fixedPoint: FixedPoint)
	{
		self = fixedPoint.toDouble()
	}
}

extension Double: ConvertibleToFixedPoint
{
	/// Returns the Double as a FixedPoint
	@inline(__always) public func toFixed() -> FixedPoint
	{
		return FixedPoint(withRaw: FixedPoint.FixedType(self * Double(1 << FixedPoint.kFractionalBits)))
	}
}

extension Double: ExpressibleByFixedPointLiteral
{
	/// Creates an instance initialized to the specified FixedPoint value.
	@inline(__always) public init(fixedPointLiteral value: FixedPoint)
	{
		self = value.toDouble()
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Codable
// ---------------------------------------------------------------------------------------------------------------------------------

extension FixedPoint: Codable
{
	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !value.encode(into: &data) { return false }
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> FixedPoint?
	{
		guard let value = FixedType.decode(from: data, consumed: &consumed) else { return nil }
		return FixedPoint(withRaw: value)
	}
}
