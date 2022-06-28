//
//  Vector.swift
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

// ---------------------------------------------------------------------------------------------------------------------------------
// Constants (mathematics)
// ---------------------------------------------------------------------------------------------------------------------------------

/// Math constant: PI
private let kPI: Real = 3.141592654

/// Math constant: convert from degrees to radians
private let kDegToRad: Real = kPI / 180.0

/// Math constant: convert from radians to degrees
private let kRadToDeg: Real = 180.0 / kPI

/// Represents a 2-dimensional vector consisting of X and Y coordinates
public struct Vector: Arithmeticable
{
	/// Required for ExpressibleByIntegerLiteral
	public typealias IntegerLiteralType = Int

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The X coordinate
	public var x: Real

	/// The Y coordinate
	public var y: Real

	/// A constant representing a Vector of (0.0, 0.0)
	static let kZero = Vector(x: 0, y: 0)

	/// A constant representing a Vector of (1.0, 1.0)
	static let kOne = Vector(x: 1, y: 1)

	/// A constant representing a Vector of (0.5, 0.5)
	static let kHalf = Vector(x: 0.5, y: 0.5)

	/// Get or set the magnitude of this Vector
	public var length: Real
	{
		get
		{
			return Real(sqrt(Double(x * x + y * y)))
		}
		set
		{
			let len = length
			let q = length == 0 ? 0 : newValue / len
			x *= q
			y *= q
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a Vector to (0, 0)
	@inline(__always) public init()
	{
		x = 0
		y = 0
	}

	/// Initialize a Vector from two Real coordinates
	@inline(__always) public init(x: Real, y: Real)
	{
		self.x = x
		self.y = y
	}

	/// Initialize a Vector from a single Real value
	@inline(__always) public init(_ value: Real)
	{
		self.x = value
		self.y = value
	}

	/// Initialize a Vector from two integer coordinates
	@inline(__always) public init(x: Int, y: Int)
	{
		self.x = Real(x)
		self.y = Real(y)
	}

	/// Initialize a Vector from a single integer value
	@inline(__always) public init(integerLiteral value: Int)
	{
		self.x = Real(value)
		self.y = self.x
	}

	/// Initialize a Vector from two FixedPoint coordinates
	@inline(__always) public init(x: ConvertibleToFixedPoint, y: ConvertibleToFixedPoint)
	{
		self.x = Real(x.toFixed())
		self.y = Real(y.toFixed())
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Conversion
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns this Vector as a Point by chopping off the fractional component
	@inline(__always) public func chopToPoint() -> IVector
	{
		return IVector(x: x.roundTowardZero(), y: y.roundTowardZero())
	}

	/// Returns this Vector as a Point by rounding the values to the nearest integer
	@inline(__always) public func roundToPoint() -> IVector
	{
		return IVector(x: x.roundToNearest(), y: y.roundToNearest())
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Arithmetic
	// -----------------------------------------------------------------------------------------------------------------------------

	@inline(__always) public static func ^ (left: Vector, right: Vector) -> Real
	{
		return left.dot(right)
	}

	@inline(__always) public static func + (left: Vector, right: Vector) -> Vector
	{
		var result = Vector(x: left.x, y: left.y)
		result += right
		return result
	}

	@inline(__always) public static func + (left: Vector, right: Real) -> Vector
	{
		var result = Vector(x: left.x, y: left.y)
		result += right
		return result
	}

	@inline(__always) public static func += (left: inout Vector, right: Vector)
	{
		left.x += right.x
		left.y += right.y
	}

	@inline(__always) public static func += (left: inout Vector, right: Real)
	{
		left.x += right
		left.y += right
	}

	@inline(__always) public static func - (left: Vector, right: Vector) -> Vector
	{
		var result = Vector(x: left.x, y: left.y)
		result -= right
		return result
	}

	@inline(__always) public static func - (left: Vector, right: Real) -> Vector
	{
		var result = Vector(x: left.x, y: left.y)
		result -= right
		return result
	}

	@inline(__always) public static func -= (left: inout Vector, right: Vector)
	{
		left.x -= right.x
		left.y -= right.y
	}

	@inline(__always) public static func -= (left: inout Vector, right: Real)
	{
		left.x -= right
		left.y -= right
	}

	@inline(__always) public static func * (left: Vector, right: Vector) -> Vector
	{
		var result = Vector(x: left.x, y: left.y)
		result *= right
		return result
	}

	@inline(__always) public static func * (left: Vector, right: Real) -> Vector
	{
		var result = Vector(x: left.x, y: left.y)
		result *= right
		return result
	}

	@inline(__always) public static func *= (left: inout Vector, right: Vector)
	{
		left.x *= right.x
		left.y *= right.y
	}

	@inline(__always) public static func *= (left: inout Vector, right: Real)
	{
		left.x *= right
		left.y *= right
	}

	@inline(__always) public static func / (left: Vector, right: Vector) -> Vector
	{
		var result = Vector(x: left.x, y: left.y)
		result /= right
		return result
	}

	@inline(__always) public static func / (left: Vector, right: Real) -> Vector
	{
		var result = Vector(x: left.x, y: left.y)
		result /= right
		return result
	}

	@inline(__always) public static func /= (left: inout Vector, right: Vector)
	{
		left.x /= right.x
		left.y /= right.y
	}

	@inline(__always) public static func /= (left: inout Vector, right: Real)
	{
		left.x /= right
		left.y /= right
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Negation
	// -----------------------------------------------------------------------------------------------------------------------------

	@inline(__always) public static prefix func - (v: Vector) -> Vector
	{
		return Vector(x: -v.x, y: -v.y)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Equivalence
	// -----------------------------------------------------------------------------------------------------------------------------

	@inline(__always) public static func == (left: Vector, right: Vector) -> Bool
	{
		return left.x == right.x && left.y == left.y
	}

	@inline(__always) public static func == (left: Vector, right: Real) -> Bool
	{
		return left.x == right && left.y == right
	}

	@inline(__always) public static func != (left: Vector, right: Vector) -> Bool
	{
		return !(left == right)
	}

	@inline(__always) public static func != (left: Vector, right: Real) -> Bool
	{
		return !(left == right)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Math functions
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the distance between two Vectors
	@inline(__always) public func distance(to other: Vector) -> Real
	{
		return (self - other).length
	}

	/// Returns a Vector containing the absolute value of each component
	@inline(__always) public func abs() -> Vector
	{
		return Vector(x: Swift.abs(x), y: Swift.abs(y))
	}

	/// Returns the maximum of the two components
	@inline(__always) public func max() -> Real
	{
		return Swift.max(x, y)
	}

	/// Returns the minimum of the two components
	@inline(__always) public func min() -> Real
	{
		return Swift.min(x, y)
	}

	/// Normalizes the vector to a length of 1.0
	@inline(__always) public mutating func normalize()
	{
		length = 1.0
	}

	/// Returns a normalized vector (see normalize())
	@inline(__always) public func normal() -> Vector
	{
		var result = self
		result.normalize()
		return result
	}

	/// Returns the dot product of two Vectors
	@inline(__always) public func dot(_ vector: Vector) -> Real
	{
		return x * vector.x + y * vector.y
	}

	/// 2D cross product (from http://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect)
	@inline(__always) public func crossMagnitude(_ vector: Vector) -> Real
	{
		return x * vector.y - y * vector.x
	}

	/// Returns a vector of a given length
	@inline(__always) public func ofLength(_ length: Real) -> Vector
	{
		var result = self
		result.length = length
		return result
	}

	/// Rotates the Vector clockwise by the given number of degrees
	public mutating func rotate(degrees: Real)
	{
		let radians = degrees * kDegToRad
		let sr = Real(sin(Double(radians)))
		let cr = Real(cos(Double(radians)))
		let rx = x * cr - y * sr
		let ry = y * cr + x * sr
		x = rx
		y = ry
	}

	/// Returns a rotated Vector (see rotate(degrees:))
	public func rotated(degrees: Real) -> Vector
	{
		var result = self
		result.rotate(degrees: degrees)
		return result
	}

	/// Swaps the components of the Vector
	@inline(__always) public mutating func swapComponents()
	{
		let _y = y
		y = x
		x = _y
	}

	/// Returns a Vector with the components swapped (see swapComponents())
	@inline(__always) public func swappedComponents() -> Vector
	{
		var result = self
		result.swapComponents()
		return result
	}

	/// Returns the angle in degrees between two vectors
	public func angleDegrees(to vector: Vector) -> Real
	{
		var ang = Real(atan2(Double(y), Double(x)) - atan2(Double(vector.y), Double(vector.x)))
		if ang > kPI
		{
			ang -= kPI * 2
		}
		else
		if ang < -kPI
		{
			ang += kPI * 2
		}
		return ang * kRadToDeg
	}

	/// Returns t, the distance to the intersection of two rays (p0, v0) and (p1, v1)
	///
	/// This is intended for performance: rays must have an intersection and must not be parallel
	@inline(__always) public static func rayIntersect(p0: Vector, v0: Vector, p1: Vector, v1: Vector) -> Real
	{
		return v1.crossMagnitude(p1-p0) / v1.crossMagnitude(v0)
	}

	/// Returns a vector projected to the edges of the given rect
	public func project(onto rect: Rect<Int>, along normal: Vector) -> Vector
	{
		let rectNormalEdge = Vector(x: normal.x > 0 ? rect.maxX : rect.minX, y: normal.y > 0 ? rect.maxY : rect.minY)

		// If the normal is perfectly vertical or horizontal, just find the point on the edge that our normal points towards
		if normal.x == 0
		{
			return Vector(x: x, y: rectNormalEdge.y)
		}
		else if normal.y == 0
		{
			return Vector(x: rectNormalEdge.x, y: y)
		}

		let t = Vector.rayIntersect(p0: self, v0: normal, p1: Vector(x: rectNormalEdge.x, y: 0), v1: Vector(x: 0, y: 1))
		let u = Vector.rayIntersect(p0: self, v0: normal, p1: Vector(x: 0, y: rectNormalEdge.y), v1: Vector(x: 1, y: 0))

		return self + normal * (Swift.abs(t) < Swift.abs(u) ? t : u)
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension Vector: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		return String(format: "x[%.3f] y[%.3f]", arguments: [Float(x), Float(y)])
	}
}
