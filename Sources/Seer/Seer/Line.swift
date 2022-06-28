//
//  Line.swift
//  Seer
//
//  Created by Paul Nettle on 11/25/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// Defines a discreet 2-dimensional line, defined with two Vector objects
public final class Line: Equatable
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The starting point of the line
	public private(set) var p0: Vector

	/// The ending point of the line
	public private(set) var p1: Vector

	/// Returns the line as a vector pointing in the direction of p0 -> p1
	public var vector: Vector
	{
		return p1 - p0
	}

	/// The length of the line
	public var length: Real
	{
		return p0.distance(to: p1)
	}

	/// The center point of the line
	public var center: Vector
	{
		return (p0 + p1) / Real(2)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a line (0, 0) - (0, 0)
	public init()
	{
		p0 = Vector()
		p1 = Vector()
	}

	/// Initialize a line from another line
	public init(line: Line)
	{
		self.p0 = line.p0
		self.p1 = line.p1
	}

	/// Initialize a line from two vectors
	public init(p0: Vector, p1: Vector)
	{
		self.p0 = p0
		self.p1 = p1
	}

	/// Initialize a line from two points
	public init(p0: IVector, p1: IVector)
	{
		self.p0 = p0.toVector()
		self.p1 = p1.toVector()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Mathematics
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Rotates the line about its center by a given number of degrees
	public func rotate(degrees: Real)
	{
		let center = self.center
		p0 = (p0 - center).rotated(degrees: degrees) + center
		p1 = (p1 - center).rotated(degrees: degrees) + center
	}

	/// Returns a rotated line (see rotate(degrees:))
	public func rotated(degrees: Real) -> Line
	{
		let line = Line(line: self)
		line.rotate(degrees: degrees)
		return line
	}

	/// Projects a point onto the nearest point on the line
	public func nearestPointOnLine(to point: Vector) -> Vector
	{
		return p0 + vector.ofLength(vector.normal() ^ (point - p0))
	}

	/// Returns the distance of the point to the line's vector
	public func distance(to point: Vector) -> Real
	{
		let nearest = nearestPointOnLine(to: point)
		return nearest.distance(to: point)
	}

	/// Returns a normalized vector that is perpendicular to the line (rotated +90 degrees)
	public var perpendicularNormal: Vector
	{
		return vector.rotated(degrees: 90).normal()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Integer math
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Chops a line's points to integer boundaries [4.3, 7.78] - [8.1, 12.0] becomes [4, 7] - [8, 12]
	public func chopToIntegerBoundaries()
	{
		p0 = p0.chopToPoint().toVector()
		p1 = p1.chopToPoint().toVector()
	}

	/// Returns a line whose coordinates have been chopped to integer boundaries
	///
	/// See chopToIntegerBoundaries() for more details
	public func choppedToIntegerBoundaries() -> Line
	{
		let line = Line(line: self)
		line.chopToIntegerBoundaries()
		return line
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Sample collection
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Samples the line and returns the associated SampleLine with the sampled results.
	///
	/// Note that the resulting SampleLine's points may not match those of this line as it may have been clipped.
	///
	/// If the clipped line does not intersect the image's rect, the return value will be nil
	public func sample(from image: LumaBuffer, invertSampleLuma: Bool) -> SampleLine?
	{
		let sampleLine = SampleLine(line: self)
		if !sampleLine.sample(from: image, invertSampleLuma: invertSampleLuma) { return nil }
		return sampleLine
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Equatable
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns a Boolean value indicating whether two values are equal.
	///
	/// Equality is the inverse of inequality. For any values `a` and `b`,
	/// `a == b` implies that `a != b` is `false`.
	///
	/// - Parameters:
	///   - lhs: A value to compare.
	///   - rhs: Another value to compare.
	public static func == (lhs: Line, rhs: Line) -> Bool
	{
		return lhs.p0 == rhs.p0 && lhs.p1 == rhs.p1
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Extend the line in both directions by a given distance
	///
	/// Note that the resulting line length will be (initial_length + distance * 2)
	public func extend(distance: Real)
	{
		let vector = self.vector.ofLength(distance)
		p0 -= vector
		p1 += vector
	}

	/// Extend the line in both directions by a given ratio of the length
	public func extend(ratio: Real)
	{
		let vector = self.vector * (ratio - 1.0)
		p0 -= vector
		p1 += vector
	}

	/// Returns an extended line (see extend(distance:))
	public func extended(distance: Real) -> Line
	{
		let line = Line(line: self)
		line.extend(distance: distance)
		return line
	}

	/// Returns an extended line (see extend(ratio:))
	public func extended(ratio: Real) -> Line
	{
		let line = Line(line: self)
		line.extend(ratio: ratio)
		return line
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension Line: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		return "p0[\(String(describing: p0))], p1[\(String(describing: p1))]"
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Arithmetic operators
// ---------------------------------------------------------------------------------------------------------------------------------

extension Line
{
	public static func + (left: Line, right: Real) -> Line
	{
		return Line(p0: left.p0 + right, p1: left.p1 + right)
	}

	public static func + (left: Line, right: Vector) -> Line
	{
		return Line(p0: left.p0 + right, p1: left.p1 + right)
	}

	public static func + (left: Line, right: Line) -> Line
	{
		return Line(p0: left.p0 + right.p0, p1: left.p1 + right.p1)
	}

	public static func - (left: Line, right: Real) -> Line
	{
		return Line(p0: left.p0 - right, p1: left.p1 - right)
	}

	public static func - (left: Line, right: Vector) -> Line
	{
		return Line(p0: left.p0 - right, p1: left.p1 - right)
	}

	public static func - (left: Line, right: Line) -> Line
	{
		return Line(p0: left.p0 - right.p0, p1: left.p1 - right.p1)
	}

	public static func * (left: Line, right: Real) -> Line
	{
		return Line(p0: left.p0 * right, p1: left.p1 * right)
	}

	public static func * (left: Line, right: Vector) -> Line
	{
		return Line(p0: left.p0 * right, p1: left.p1 * right)
	}

	public static func * (left: Line, right: Line) -> Line
	{
		return Line(p0: left.p0 * right.p0, p1: left.p1 * right.p1)
	}

	public static func / (left: Line, right: Real) -> Line
	{
		return Line(p0: left.p0 / right, p1: left.p1 / right)
	}

	public static func / (left: Line, right: Vector) -> Line
	{
		return Line(p0: left.p0 / right, p1: left.p1 / right)
	}

	public static func / (left: Line, right: Line) -> Line
	{
		return Line(p0: left.p0 / right.p0, p1: left.p1 / right.p1)
	}
}
