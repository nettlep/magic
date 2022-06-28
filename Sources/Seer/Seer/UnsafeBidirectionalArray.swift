//
//  UnsafeBidirectionalArray.swift
//  Seer
//
//  Created by Paul Nettle on 2/18/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
#if os(iOS)
import MinionIOS
#else
import Minion
#endif

/// An array which can be populated in constant time at both ends
public struct UnsafeBidirectionalArray<Element>
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The starting index, representing the index of the front-most element of the array. Note that this may not point to an
	/// actual element if `count` is zero.
	///
	/// This value is only decremented when adding elements to the front of the array.
	public private(set) var frontIndex: Int

	/// The number of elements stored in the array
	public private(set) var count: Int

	/// The total storage capacity (including positive and negative indices)
	public private(set) var capacity: Int

	/// Data storage for the array
	public private(set) var data: UnsafeMutableArray<Element>

	/// Data storage for the array
	public fileprivate(set) var interpolatedData: UnsafeMutableArray<Element>

	/// Index into the array relative to `frontIndex`
	public subscript(index: Int) -> Element
	{
		assert(index < count)
		return data[frontIndex + index]
	}

	/// Returns the first element in the array
	///
	/// This is likely, the most recent element to be pushed to the front (via `pushFront`). However, if no elements have been
	/// pushed to the front, the element will be the first element pushed to the back (via `pushBack`).
	public var front: Element?
	{
		assert(count > 0)
		if count == 0 { return nil }
		return data[frontIndex]
	}

	/// Returns the last element in the array
	///
	/// This is likely, the most recent element to be pushed to the back (via `pushBack`). However, if no elements have been pushed
	/// to the back, the element returned will be the first element pushed to the front (via `pushFront`).
	public var back: Element?
	{
		assert(count > 0)
		if count == 0 { return nil }
		return data[frontIndex + count - 1]
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	// capacity specifies how much we can grow in each direction - total allocation is 2x this amount. In addition, it must be odd,
	// so the capacity may also grow by 1 to make it so
	public init(withCapacity capacity: Int)
	{
		self.capacity = (capacity * 2)
		self.frontIndex = self.capacity / 2
		self.count = 0
		self.data = UnsafeMutableArray<Element>(withCapacity: self.capacity)
		self.interpolatedData = UnsafeMutableArray<Element>(withCapacity: self.capacity)

		// Make the data array appear to be full so we can manipulate it manually
		self.data.count = self.data.capacity
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Memory management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Free all memory allocated by the array
	///
	/// It is safe to call this member multiple times; if the array has no capacity, this method does nothing other than to ensure
	/// that `capacity` and `count` are set to 0.
	@inline(__always) public mutating func free()
	{
		data.free()
		interpolatedData.free()
		capacity = 0
		count = 0
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Element management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Add an element to the front of the array
	@inline(__always) public mutating func pushFront(_ value: Element)
	{
		assert(count < capacity)
		assert(frontIndex > 0)

		frontIndex -= 1
		data._rawPointer[frontIndex] = value

		count += 1
	}

	/// Remove `count` elements from the front of the array and returns the last element to be removed
	///
	/// If the array isn't large enough to remove `count` elements, then the method does nothing and returns nil.
	@inline(__always) public mutating func popFront(count popCount: Int = 1) -> Element?
	{
		if popCount < 0 || popCount > count { return nil }

		frontIndex += popCount
		count -= popCount

		// Return the last element that was popped
		return data._rawPointer[frontIndex-1]
	}

	/// Add an element to the back of the array
	@inline(__always) public mutating func pushBack(_ value: Element)
	{
		assert(count < capacity)
		assert(frontIndex + count < capacity)

		data._rawPointer[frontIndex + count] = value

		count += 1
	}

	/// Remove `count` elements from the back of the array and returns the last element to be removed
	///
	/// If the array isn't large enough to remove `count` elements, then the method does nothing and returns nil.
	@inline(__always) public mutating func popBack(count popCount: Int = 1) -> Element?
	{
		if popCount < 0 || popCount > count { return nil }

		count -= popCount

		// Return the last element that was popped
		return data._rawPointer[frontIndex + count]
	}

	/// Empty the array and reset origin to the center
	///
	/// In order to be efficient, the memory for previous elements is left untouched
	@inline(__always) public mutating func removeAll()
	{
		frontIndex = capacity / 2
		count = 0
	}
}

// -----------------------------------------------------------------------------------------------------------------------------
// Interpolation & filtering
// -----------------------------------------------------------------------------------------------------------------------------

/// Here we add special functionality for interpolating sparse IVector arrays into contiguous arrays as well as filtering IVector
/// data.
extension UnsafeBidirectionalArray where Element == IVector
{
	/// Given an array of IVectors which contains gaps along its predominant axis, this method will return a continuous array
	/// in which the gaps are filled in by interpolation of the neighboring elements and filtered.
	///
	/// To force this method to treat a specific axis as predominant, set `mask` to an IVector containing the predominant axis. In
	/// other words, use:
	///
	///     IVector(1, 0): X predominant axis - interpolate Y values along the X axis
	///     IVector(0, 1): Y predominant axis - interpolate X values along the Y axis
	///
	/// For details on the filtering technique, see `filter()`. You can prevent filtering by setting 'filter' to `false`.
	///
	/// This method will populate the `interpolatedData` array.
	public mutating func interpolateGaps(withMask mask: IVector? = nil, filter doFilter: Bool = true) -> UnsafeMutableArray<IVector>
	{
		// Clean up our array
		interpolatedData.removeAll()

		// No data? Return the empty array
		if count == 0 { return interpolatedData }

		// Add the first point
		var head = data[frontIndex]
		interpolatedData.add(head)

		// Early out to avoid interpolation if we only have one element
		if count == 1 { return interpolatedData }

		// The end index, which we'll use for the interpolation loop
		let end = frontIndex + count

		// Our last point, so we can determine the sign of the direction that we're interpolating
		let last = data[end - 1]

		// Mask used to determine the interpolation direction (X or Y)
		//
		// This value must be either (1, 0) or (0, 1). That is, the absolute normal of the direction of interpolation
		let interpolationMask = mask ?? (last - head).orthoNormalMask
		assert((interpolationMask.x == 0 && interpolationMask.y == 1) || (interpolationMask.x == 1 && interpolationMask.y == 0))

		// Interpolation on X
		if interpolationMask.x != 0
		{
			let xSign = (last - head).x.sign()
			for i in frontIndex+1..<end
			{
				// Grab the tail
				let tail = data[i]

				// Interpolate?
				let delta = tail.y - head.y
				let interpDistance = abs(tail.x - head.x)
				if interpDistance > 1
				{
					// Avoid overflows
					if interpDistance > (interpolatedData.capacity - interpolatedData.count - 1)
					{
						gLogger.error("Bi-directional interpolation overlow detected")
						break
					}

					// Add the intermediate values
					let dy = delta.toFixed() / interpDistance
					var x = head.x
					var y = head.y.toFixed()
					for _ in 1..<interpDistance
					{
						x += xSign
						y += dy
						let newVector = IVector(x: x, y: y.floor())
						interpolatedData.add(newVector)
					}
				}

				// Add the tail
				interpolatedData.add(tail)
				head = tail
			}
		}
		// Interpolation on Y
		else if interpolationMask.y != 0
		{
			let ySign = (last - head).y.sign()
			for i in frontIndex+1..<end
			{
				// Grab the tail
				let tail = data[i]

				// Interpolate?
				let delta = tail.x - head.x
				let interpDistance = abs(tail.y - head.y)
				if interpDistance > 1
				{
					// Avoid overflows
					if interpDistance > (interpolatedData.capacity - interpolatedData.count - 1)
					{
						gLogger.error("Bi-directional interpolation overlow detected")
						break
					}

					// Add the intermediate values
					let dx = delta.toFixed() / interpDistance
					var y = head.y
					var x = head.x.toFixed()
					for _ in 1..<interpDistance
					{
						x += dx
						y += ySign
						let newVector = IVector(x: x.floor(), y: y)
						interpolatedData.add(newVector)
					}
				}

				// Add the tail
				interpolatedData.add(tail)
				head = tail
			}
		}

		if doFilter
		{
			return filter()
		}

		return interpolatedData
	}

	/// Simply performs an average of the IVector data perpendicular to the overall direction of the line array of samples
	///
	/// The head and tail are also filtered by specifically averaging them with their neighbor
	private mutating func filter() -> UnsafeMutableArray<IVector>
	{
		// Not enough data? Return the unfiltered array
		if interpolatedData.count < 2 { return interpolatedData }

		// Get the full range and calculate the mask
		let end = interpolatedData.count - 1
		let head = interpolatedData[0]
		let last = interpolatedData[end]
		let interpolationMask = (last - head).orthoNormalMask

		var a = IVector()
		var b = head
		var c = interpolatedData[1]

		// Filter on X
		if interpolationMask.x != 0
		{
			for i in 1..<end
			{
				// Shift down
				a = b
				b = c
				c = interpolatedData[i+1]

				// Filter
				let filtered = (a.y + b.y * 2 + c.y) / 4
				interpolatedData[i] = IVector(x: b.x, y: filtered)
			}

			// Filter first entry
			var filtered = (interpolatedData[0].y + interpolatedData[1].y) / 2
			interpolatedData[0] = IVector(x: interpolatedData[0].x, y: filtered)

			// Filter last entry
			filtered = (interpolatedData[end].y + interpolatedData[end-1].y) / 2
			interpolatedData[end] = IVector(x: interpolatedData[end].x, y: filtered)
		}
		// Filter on Y
		else if interpolationMask.y != 0
		{
			for i in 1..<end
			{
				// Shift down
				a = b
				b = c
				c = interpolatedData[i+1]

				// Filter
				let filtered = (a.x + b.x * 2 + c.x) / 4
				interpolatedData[i] = IVector(x: filtered, y: b.y)
			}

			// Filter first entry
			var filtered = (interpolatedData[0].x + interpolatedData[1].x) / 2
			interpolatedData[0] = IVector(x: filtered, y: interpolatedData[0].y)

			// Filter last entry
			filtered = (interpolatedData[end].x + interpolatedData[end-1].x) / 2
			interpolatedData[end] = IVector(x: filtered, y: interpolatedData[end].y)
		}

		return interpolatedData
	}
}
