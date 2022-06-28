//
//  Rect.swift
//  Seer
//
//  Created by Paul Nettle on 1/4/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// A rectangle, defined with inclusive Min/Max values for X and Y
public struct Rect<T: Arithmeticable & Comparable & ConvertibleToFixedPoint>
{
	/// The minimum X of the rect
	public var minX: T

	/// The minimum Y of the rect
	public var minY: T

	/// The maximum X of the rect
	public var maxX: T

	/// The maximum Y of the rect
	public var maxY: T

	/// The width of the rectangle (maxX - minX + 1)
	public var width: T { return maxX - minX + 1 }

	/// The width of the rectangle (maxY - minY + 1)
	public var height: T { return maxY - minY + 1 }

	/// Returns the center of the rect
	public var center: Vector
	{
		let x = (minX + maxX).toFixed()
		let y = (minY + maxY).toFixed()
		return Vector(x: Real(x / 2), y: Real(y / 2))
	}

	/// Initialize a rect with defaults (all zeros)
	public init()
	{
		self.minX = 0
		self.minY = 0
		self.maxX = 0
		self.maxY = 0
	}

	/// Initialize a rect from the essentials
	///
	/// Note that ordering is important. If the max value is less than the min value, then the dimension (width/height) will
	/// be negative.
	public init(minX: T, minY: T, maxX: T, maxY: T)
	{
		self.minX = minX
		self.minY = minY
		self.maxX = maxX
		self.maxY = maxY
	}

	/// Initialize a rect from location and dimensions
	///
	/// Note that the maxX maxY values are inclusive and therefore, are equal to e.g. [minX + width - 1]
	public init(x: T, y: T, width: T, height: T)
	{
		self.minX = x
		self.minY = y
		self.maxX = x + width - 1
		self.maxY = y + height - 1
	}

	///Initialize from another rect
	public init(rect: Rect)
	{
		minX = rect.minX
		minY = rect.minY
		maxX = rect.maxX
		maxY = rect.maxY
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Clipping and intersection
	// -----------------------------------------------------------------------------------------------------------------------------

	public func intersected(with rect: Rect) -> Rect?
	{
		var r = Rect(rect: rect)
		if !r.intersect(with: self) { return nil }
		return r
	}

	public mutating func intersect(with rect: Rect) -> Bool
	{
		// Non-overlapping test
		if maxX < rect.minX || minX > rect.maxX || maxY < rect.minY || minY > rect.maxY { return false }

		// Perform overlap intersection
		if minX < rect.minX { minX = rect.minX }
		if maxX > rect.maxX { maxX = rect.maxX }
		if minY < rect.minY { minY = rect.minY }
		if maxY > rect.maxY { maxY = rect.maxY }
		return true
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns true if the point intersects the extents of the Rect, otherwise false
	public func contains(point p: IVector) -> Bool
	{
		return p.x.toFixed() >= minX.toFixed() && p.x.toFixed() <= maxX.toFixed() && p.y.toFixed() >= minY.toFixed() && p.y.toFixed() <= maxY.toFixed()
	}

	/// Returns true if the point intersects the extents of the Rect, otherwise false
	public func contains(point p: Vector) -> Bool
	{
		return p.x.toFixed() >= minX.toFixed() && p.x.toFixed() <= maxX.toFixed() && p.y.toFixed() >= minY.toFixed() && p.y.toFixed() <= maxY.toFixed()
	}

	/// Move the rect's min/max toward the center by a given amount
	///
	/// Note that the reduction is applied to both, the min and max, therefore the total dimension will be reduced by
	/// (amount * 2) in each direction.
	public mutating func reduce(by amount: T)
	{
		minX += amount
		minY += amount
		maxX -= amount
		maxY -= amount
	}

	/// Returns a Rect reduced by `amount`
	///
	/// For important implementation details, see reduce(amount:)
	public func reduced(by amount: T) -> Rect
	{
		var rect = Rect(rect: self)
		rect.reduce(by: amount)
		return rect
	}

	/// Move the rect's min/max away from the center by a given amount
	///
	/// Note that the expansion is applied to both, the min and max, therefore the total dimension will be expanded by
	/// (amount * 2) in each direction.
	public mutating func expand(by amount: T)
	{
		minX -= amount
		minY -= amount
		maxX += amount
		maxY += amount
	}

	/// Returns a Rect expanded by `amount`
	///
	/// For important implementation details, see expand(amount:)
	public func expanded(by amount: T) -> Rect
	{
		var rect = Rect(rect: self)
		rect.expand(by: amount)
		return rect
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension Rect: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		return "X[\(minX) - \(maxX)], Y[\(minY) - \(maxY)]"
	}
}
