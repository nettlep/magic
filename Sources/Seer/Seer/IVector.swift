//
//  IVector.swift
//  Seer
//
//  Created by Paul Nettle on 1/6/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// Represents an X/Y coordinate within an image
public struct IVector: Arithmeticable
{
	/// Required for ExpressibleByIntegerLiteral
	public typealias IntegerLiteralType = Int

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The X coordinate
	public var x: Int

	/// The Y coordinate
	public var y: Int

	/// Get or set the magnitude of this Vector in FixedPoint
	///
	/// When setting the length, the x/y components are rounded to the nearest integer
	public var length: FixedPoint
	{
		get
		{
			return FixedPoint(sqrt(Double(x * x + y * y)))
		}
		set
		{
			let len = length
			let q = length == 0 ? 0 : newValue / len
			x = (q * x).roundToNearest()
			y = (q * y).roundToNearest()
		}
	}

	/// Returns an orthogonal normal for the vector, or a Zero vector (x=0, y=0) if `self` is a zero vector
	///
	/// An Orthogonal Normal is a signed normal in which one component is always zero and the other component is a signed unit
	/// value (either +1 or -1). The direction is determined by the component with the greater magnitude (absolute value.)
	///
	/// Exceptional conditions:
	///
	///		* If both components are zero (a zero vector) then the result will be a zero vector
	///		* If both components have the same magnitude (|x| == |y|) then X will be treated as if it has the greater magnitude
	///
	///	Note that if both components have the same magnitude (including both equal to 0) then the result will be IVector(0, 0)
	///
	/// Examples:
	///		IVector(7, 4) -> IVector(1, 0)
	///		IVector(107, -108) -> IVector(0, -1)
	///		IVector(15, 15) -> IVector(1, 0)
	///		IVector(-5, 5) -> IVector(-1, 0)
	///		IVector(0, 0) -> IVector(0, 0)
	public var orthoNormal: IVector
	{
		let absDelta = abs()
		if absDelta.x >= absDelta.y
		{
			if      x > 0 { return IVector(x: 1, y: 0) }
			else if x < 0 { return IVector(x: -1, y: 0) }
			else
			{
				assert(x == 0 && y == 0)
				return self
			}
		}

		if y > 0 { return IVector(x: 0, y: 1) }
		else     { return IVector(x: 0, y: -1) }
	}

	/// Returns an unsigned orthogonal normal for the vector
	///
	/// See `orthoNormal` for more information on orthogonal normals.
	///
	/// Simply using the absolute value of an orthogonal normal provides an IVector that can be used as a directional mask. That
	/// is, multiplying an orthoNormalMask by an IVector returns the vector along a single axis.
	public var orthoNormalMask: IVector
	{
		let absDelta = abs()
		if absDelta.x >= absDelta.y
		{
			if absDelta.x > 0
			{
				return IVector(x: 1, y: 0)
			}
			else
			{
				assert(x == 0 && y == 0)
				return self
			}
		}

		return IVector(x: 0, y: 1)
	}

	/// Returns an orthogonal normal that is perpendicular to the input normal, rotated clockwise.
	///
	/// See `orthoNormal` for more information on orthogonal normals.
	///
	/// Calling this method sequentially with a starting IVector of (2, -9) will produce the following output (note the clockwise
	/// direction of rotation):
	///
	///		(0, -1) -> (1, 0) -> (0, 1) -> (-1, 0) -> (0, -1)
	public var perpOrthoNormal: IVector
	{
		let absDelta = abs()
		if absDelta.x >= absDelta.y
		{
			if      x > 0 { return IVector(x: 0, y: 1) }
			else if x < 0 { return IVector(x: 0, y: -1) }
			else
			{
				assert(x == 0 && y == 0)
				return self
			}
		}

		if y > 0 { return IVector(x: -1, y: 0) }
		else     { return IVector(x: 1, y: 0) }
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a IVector to (0, 0)
	@inline(__always) public init()
	{
		x = 0
		y = 0
	}

	/// Initialize a IVector from two integer coordinates
	@inline(__always) public init(x: Int, y: Int)
	{
		self.x = x
		self.y = y
	}

	/// Initialize a IVector from a single integer value
	@inline(__always) public init(integerLiteral value: Int)
	{
		self.x = value
		self.y = value
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Conversion
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns this IVector as a Vector
	@inline(__always) public func toVector() -> Vector
	{
		return Vector(x: x, y: y)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Vector operations
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the orthogonal distance between two IVectors
	///
	/// This method returns the distance in either X or Y (whichever is greater)
	@inline(__always) public func orthoDistance(to other: IVector) -> Int
	{
		return (self - other).abs().max()
	}

	/// Returns the distance between two IVectors
	@inline(__always) public func distance(to other: IVector) -> FixedPoint
	{
		return (self - other).length
	}

	/// Returns a normalized vector (see normalize())
	@inline(__always) public func normalized() -> IVector
	{
		var result = self
		result.normalize()
		return result
	}

	/// Normalizes the IVector components and converts them into FixedPoint formatted values
	///
	/// This is handy for use with standard arithmetic operations in order to preserve some precision during those operations.
	///
	/// IMPORTANT: To retrieve the final value, use denormalize()
	@inline(__always) public mutating func normalize()
	{
		let len = length
		if len == 0
		{
			x = 0
			y = 0
		}
		else
		{
			x = Int((FixedPoint(x) / len).value)
			y = Int((FixedPoint(y) / len).value)
		}
	}

	/// Returns a de-normalized vector (see denormalize())
	@inline(__always) public func denormalized() -> IVector
	{
		var result = self
		result.denormalize()
		return result
	}

	/// De-normalizes the IVector components from FixedPoint formatted values into integer values. This function is to be used in
	/// conjunction with normalize().
	///
	/// By default, the result is rounded to the nearest integer. Set `rounded` to false to cause the operation to round toward zero
	/// instead.
	@inline(__always) public mutating func denormalize(rounded: Bool = true)
	{
		if rounded
		{
			x = FixedPoint(withRaw: FixedPoint.FixedType(x)).roundToNearest()
			y = FixedPoint(withRaw: FixedPoint.FixedType(y)).roundToNearest()
		}
		else
		{
			x = FixedPoint(withRaw: FixedPoint.FixedType(x)).roundTowardZero()
			y = FixedPoint(withRaw: FixedPoint.FixedType(y)).roundTowardZero()
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Arithmetic
	// -----------------------------------------------------------------------------------------------------------------------------

	@inline(__always) public static func + (left: IVector, right: IVector) -> IVector
	{
		var result = IVector(x: left.x, y: left.y)
		result += right
		return result
	}

	@inline(__always) public static func + (left: IVector, right: Int) -> IVector
	{
		var result = IVector(x: left.x, y: left.y)
		result += right
		return result
	}

	@inline(__always) public static func += (left: inout IVector, right: IVector)
	{
		left.x += right.x
		left.y += right.y
	}

	@inline(__always) public static func += (left: inout IVector, right: Int)
	{
		left.x += right
		left.y += right
	}

	@inline(__always) public static func - (left: IVector, right: IVector) -> IVector
	{
		var result = IVector(x: left.x, y: left.y)
		result -= right
		return result
	}

	@inline(__always) public static func - (left: IVector, right: Int) -> IVector
	{
		var result = IVector(x: left.x, y: left.y)
		result -= right
		return result
	}

	@inline(__always) public static func -= (left: inout IVector, right: IVector)
	{
		left.x -= right.x
		left.y -= right.y
	}

	@inline(__always) public static func -= (left: inout IVector, right: Int)
	{
		left.x -= right
		left.y -= right
	}

	@inline(__always) public static func * (left: IVector, right: IVector) -> IVector
	{
		var result = IVector(x: left.x, y: left.y)
		result *= right
		return result
	}

	@inline(__always) public static func * (left: IVector, right: Int) -> IVector
	{
		var result = IVector(x: left.x, y: left.y)
		result *= right
		return result
	}

	@inline(__always) public static func *= (left: inout IVector, right: IVector)
	{
		left.x *= right.x
		left.y *= right.y
	}

	@inline(__always) public static func *= (left: inout IVector, right: Int)
	{
		left.x *= right
		left.y *= right
	}

	@inline(__always) public static func / (left: IVector, right: IVector) -> IVector
	{
		var result = IVector(x: left.x, y: left.y)
		result /= right
		return result
	}

	@inline(__always) public static func / (left: IVector, right: Int) -> IVector
	{
		var result = IVector(x: left.x, y: left.y)
		result /= right
		return result
	}

	@inline(__always) public static func /= (left: inout IVector, right: IVector)
	{
		left.x /= right.x
		left.y /= right.y
	}

	@inline(__always) public static func /= (left: inout IVector, right: Int)
	{
		left.x /= right
		left.y /= right
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Negation
	// -----------------------------------------------------------------------------------------------------------------------------

	@inline(__always) public static prefix func - (p: IVector) -> IVector
	{
		return IVector(x: -p.x, y: -p.y)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Equivalence
	// -----------------------------------------------------------------------------------------------------------------------------

	@inline(__always) public static func == (left: IVector, right: IVector) -> Bool
	{
		return left.x == right.x && left.y == left.y
	}

	@inline(__always) public static func == (left: IVector, right: Int) -> Bool
	{
		return left.x == right && left.y == right
	}

	@inline(__always) public static func != (left: IVector, right: IVector) -> Bool
	{
		return !(left == right)
	}

	@inline(__always) public static func != (left: IVector, right: Int) -> Bool
	{
		return !(left == right)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Math functions
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns a IVector containing the absolute value of each component
	@inline(__always) public func abs() -> IVector
	{
		return IVector(x: Swift.abs(x), y: Swift.abs(y))
	}

	/// Returns the maximum of the two components
	@inline(__always) public func max() -> Int
	{
		return Swift.max(x, y)
	}

	/// Returns the minimum of the two components
	@inline(__always) public func min() -> Int
	{
		return Swift.min(x, y)
	}

	/// Swaps the components of the IVector
	@inline(__always) public mutating func swapComponents()
	{
		let _y = y
		y = x
		x = _y
	}

	/// Returns a IVector with the components swapped (see swapComponents())
	@inline(__always) public func swappedComponents() -> IVector
	{
		var result = self
		result.swapComponents()
		return result
	}

	/// Returns a vector of a given length
	@inline(__always) public func ofLength(length: Int) -> IVector
	{
		return ofLength(length: length.toFixed())
	}

	/// Returns a vector of a given length
	@inline(__always) public func ofLength(length: FixedPoint) -> IVector
	{
		var result = self
		result.length = length
		return result
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension IVector: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		return "x[\(x)] y[\(y)]"
	}
}
