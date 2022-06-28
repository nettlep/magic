//
//  UnsafeMutableArray.swift
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

/// Efficient container for storing a contiguous group of stored values
///
/// ***
/// *** IMPORTANT ***
/// ***
///
///		Do not store class objects in any way in this container. To be clear on this point, use this for built-in stored value
///		types (Int, UInt32, etc.) and structures.
///
///		If you store a structure in this container, ensure that the structure does not contain an object, all the way down the
///		chain members. Not heeding this advice will likely get you a crash right away.
///
///		In addition, you are responsible for freeing the memory allocated by calling `free()`.
///
/// **
/// ** PURPOSE
/// **
///
/// Swift's ARC is a solid and robust memory management mechanism and very helpful. However, it can lead to performance loss in
/// areas where performance is absolutely critical. Swift's arrays, though performant can still lead to unexpected performance loss
/// with range checking, copy-on-write, etc.
///
/// The goal of the UnsafeMutableArray is to provide an array that can be passed around with no ARC overhead, while allowing very
/// fast, direct-from-memory access to stored values. However, it is up to the caller to free the resources used by this array
/// by calling `free()`.
///
/// Think of an UnsafeMutableArray as an extension to UnsafeMutablePointer which contains a `count` of used elements in the array
/// along with a `capacity` of total elements the array can store.
///
/// **
/// ** USAGE AND IMPLEMENTATION DETAILS
/// **
///
///	UnsafeMutableArray has a very simple interface, akin to what you would expect from an array in C. Like a standard C array, you
/// manage the storage requirements of a UnsafeMutableArray. The array's `capacity` must be specified up front. It can be re-sized,
/// but it's up to you to control how and when tha that happens (see `ensureReservation()`).
///
/// The two primary properties, `capacity` and `count` are managed separately. `capacity` represents the total available storage
/// (in terms of the number of elements of type `T` in the array.) `count` represents the number of elements stored in the array.
///
/// Generally speaking, you are responsible for the state of the memory in the array (it is not initialized or cleared.) The one
/// exception to this is `init(repeating:count:)`. As a result clearing the array (via `removeAll` is nearly instantaneous as all
/// it has to do is to set `count` to 0.
///
/// Adding elements to the array (via `add()`) is as simple as a storing a value into the array and incrementing the `count`
/// property. However, you can directly manipulate `count`. This can be useful for operations that convert the array from one
/// representation of data into another, smaller (i.e., fewer `count` elements) representation of data.
///
/// Overruns are managed via `assert` in debug mode, but that protection goes away in optimized builds.
public struct UnsafeMutableArray<Element>
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The number of elements currently stored in the array (must always be <= capacity)
	///
	/// Writing to the `count` property in debug mode will assert that count is <= capacity, but this protection will go away in
	/// optimized (release) builds.
	public var count: Int
	{
		willSet(newValue)
		{
			assert(newValue <= capacity)
		}
	}

	/// Returns true if the count is zero, otherwise false
	public var isEmpty: Bool
	{
		return count == 0
	}

	/// The capacity of the array; the number of elements that have been allocated for this array
	///
	/// You cannot modify this value as it is set during initialization and allocation.
	public private(set) var capacity: Int

	/// The raw data of this array
	public private(set) var _rawPointer: UnsafeMutablePointer<Element>

	/// Returns a single element in the array at the given `index`
	///
	/// The bounds are checked via an `assert` in debug builds. This protection goes away in optimized (release) builds.
	public subscript(index: Int) -> Element
	{
		get
		{
			assert(index >= 0 && index < count)
			return _rawPointer[index]
		}
		set
		{
			assert(index >= 0 && index < count)
			_rawPointer[index] = newValue
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize an array with a given `capacity` representing the number of elements (of type `T`) that this array can store.
	///
	/// After initialization, the `count` property of this array will be 0.
	///
	/// The array will not grow automatically, but can be resized via `ensureReservation()`.
	public init(withCapacity capacity: Int = 1)
	{
		self.count = 0
		self.capacity = capacity
		self._rawPointer = UnsafeMutablePointer<Element>.allocate(capacity: capacity)
	}

	/// Initialize an array with the contents of another array (duplicating the `capacity`, `count` and the data in `elements`
	///
	/// Note that only `count` elements are copied from the source array's data.
	public init(_ rhs: UnsafeMutableArray<Element>)
	{
		self.init(withCapacity: rhs.capacity)

		if rhs.count > 0
		{
			self._rawPointer.assign(from: rhs._rawPointer, count: rhs.count)
			self.count = rhs.count
		}
	}

	/// Initializes an array with the given `sourceData`
	///
	/// The new array will allocate exactly `count` elements (making `count` equal to `capacity`) and copy them into the new array.
	public init(withData data: UnsafePointer<Element>, count: Int)
	{
		self.init(withCapacity: count)

		if count > 0
		{
			self._rawPointer.assign(from: data, count: count)
			self.count = count
		}
	}

	/// Initializes an array with a pointer to existing data
	///
	/// This works as a wrapper around an existing pointer so we can treat it like an array
	public init(withPointer pointer: UnsafeMutablePointer<Element>, capacity: Int, count: Int = 0)
	{
		self.count = count
		self.capacity = capacity
		self._rawPointer = pointer
	}

	/// Initializes an array with the given `array`
	///
	/// The new array will allocate the exact number of elements needed (making `count` equal to `capacity`) and copy them into the
	/// new array.
	public init(withArray array: [Element])
	{
		self.init(withCapacity: array.count)
		count = array.count

		if count > 0
		{
			for i in 0..<count
			{
				self._rawPointer[i] = array[i]
			}
		}
	}

	/// Initialize an array by allocating `count` elements (of type `T`) and setting all values equal to `repeating`
	///
	/// After this call, the array's `count` and `capacity` will both be equal to the `count` parameter.
	public init(repeating value: Element, count: Int)
	{
		self.init(withCapacity: count)
		initialize(to: value, count: count)
		self.count = count
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Memory management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Clears out the array and, if necessary, allocates more memory to meet the `newCapacity` requirements.
	///
	/// You may optionally specify a growth scalar, such that if the array needs to grow, it grows by the `newCapacity` scaled
	/// by this factor.
	///
	/// This method will never reduce the allocation and will only allocate memory if needed. In addition, the array will always
	/// be cleared. If you need to reduce the memory allocation, call `free` first.
	@inline(__always) public mutating func ensureReservation(capacity newCapacity: Int, growthScalar: FixedPoint = FixedPoint.kOne)
	{
		if capacity < newCapacity
		{
			free()

			capacity = (growthScalar * newCapacity).floor()
			_rawPointer = UnsafeMutablePointer<Element>.allocate(capacity: capacity)
		}

		removeAll()
	}

	/// Free all memory allocated by the array
	///
	/// It is safe to call this member multiple times; if the array has no capacity, this method does nothing other than to ensure
	/// that `capacity` and `count` are set to 0.
	@inline(__always) public mutating func free()
	{
		if capacity > 0
		{
			_rawPointer.deallocate()
			capacity = 0
		}
		count = 0
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Element management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initializes the contents of the array to a single value (of type `T`) and sets the count to the given `count`
	///
	/// The count is asserted to not be greater than `capacity` in debug mode, but this protection will go away in optimized
	/// (release) builds.
	@inline(__always) public mutating func initialize(to value: Element, count: Int)
	{
		assert(count <= capacity)
		self._rawPointer.initialize(repeating: value, count: count)
		self.count = count
	}

	/// Replaces the contents of the array with those from the source `array`. The current array is grown, if necessary. The final
	/// count will be that of the input array's count.
	@inline(__always) public mutating func assign(from array: UnsafeMutableArray<Element>)
	{
		assign(from: array._rawPointer, count: array.count)
	}

	/// Replaces the contents of the array with those from the source `pointer`. The current array is grown, if necessary. The
	/// final count will be that of the `count` parameter.
	@inline(__always) public mutating func assign(from pointer: UnsafePointer<Element>, count: Int)
	{
		ensureReservation(capacity: count)
		self._rawPointer.assign(from: pointer, count: count)
		self.count = count
	}

	/// Adds a value to the end of the array and increments the `count` property
	///
	/// You are required to make sure that there is room in the array for the new element. Range checking is asserted in debug mode
	/// but that protection will go away in optimized (release) builds.
	@inline(__always) public mutating func add(_ value: Element)
	{
		assert(count < capacity)
		_rawPointer[count] = value
		count += 1
	}

	/// Inserts a value at the given index and increments the `count` property
	///
	/// You are required to make sure that there is room in the array for the new element. Range checking is asserted in debug mode
	/// but that protection will go away in optimized (release) builds.
	@inline(__always) public mutating func insert(before index: Int, value: Element)
	{
		assert(count < capacity)
		let shiftCount = count - index
		for i in 0..<shiftCount { _rawPointer[count - i] = _rawPointer[count - i - 1] }
		_rawPointer[index] = value
		count += 1
	}

	/// Removes a value from the array by shifting all values after it down by one
	///
	/// You are required to make sure that the index is within range. Range checking is asserted in debug mode but that protection
	/// will go away in optimized (release) builds.
	@inline(__always) public mutating func remove(at index: Int)
	{
		assert(index >= 0 && index < count)
		count -= 1
		for i in index..<count
		{
			_rawPointer[i] = _rawPointer[i+1]
		}
	}

	/// Empties the array by setting `count` to 0
	///
	/// In order to be efficient, the memory for previous elements is left untouched. All this method does is to set `count` to 0
	@inline(__always) public mutating func removeAll()
	{
		count = 0
	}

	/// Swaps the elements at indices `a` and `b`.
	///
	/// Indicies `a` and `b` must both be valid indices in the range of the array
	@inline(__always) public mutating func swapAt(_ a: Int, _ b: Int)
	{
		assert(a >= 0 && a < count)
		assert(b >= 0 && b < count)

		swap(&_rawPointer[a], &_rawPointer[b])
	}
}
