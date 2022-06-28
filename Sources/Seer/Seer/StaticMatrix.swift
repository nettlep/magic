//
//  StaticMatrix.swift
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

/// Efficient container class for storing a constant-sized array of dynamically-sized arrays
///
/// ***
/// *** IMPORTANT ***
/// ***
///
///		Do not store class objects in any way in this container. To be clear on this point, use this for built-in stored value
///		types (Int, UInt32, etc.) and structures.
///
///		If you store a structure in this container, ensure that the structure does not contain an object, all the way down the
///		chain members.
///
///		Not heeding this advice will likely get you a crash right away.
///
/// **
/// ** PURPOSE
/// **
///
/// Swift's ARC is a solid and robust memory management mechanism and very helpful. However, it can lead to performance loss in
/// areas where performance is absolutely critical. Swift's arrays, though performant can still lead to unexpected performance loss
/// with range checking, copy-on-write, etc.
///
/// The goal of the StaticMatrix is to provide an object (StaticMatrix is a class) that can be passed around with minimal ARC
/// overhead, while allowing very fast, direct-from-memory access to a 2-dimensional set of stored values.
///
/// **
/// ** USAGE AND IMPLEMENTATION DETAILS
/// **
///
///	StaticMatrix is a very simple class, akin to what you would expect from an 2D array in C. Like a standard C array, you manage
/// the storage requirements of a StaticMatrix. The matrix's two capacity values (`rowCapacity` and `colCapacity`) must be
/// specified up front. It can be re-sized, but it's up to you to control how and when tha that happens (see `ensureReservation()`).
///
/// The three primary properties, `rowCapacity`, `colCapacity` and `count` are managed separately. `rowCapacity` and `colCapacity`
/// represent the total available storage (in terms of the number of elements of type `T` in each dimension of the matrix.) `count`
/// represents the total number of elements stored in the matrix.
///
/// Generally speaking, you are responsible for the state of the memory in the matrix (it is not initialized or cleared.) As a
/// result clearing the array (via `removeAll` is very fast as all it has to do is to set `count` to 0 and initialize each of the
/// individual column counts to 0.
///
/// The matrix is automatically allocated and freed upon de-initialization.
///
/// Adding elements to the matrix (via `add()`) is as simple as a storing a value into the matrix, incrementing the `count`
/// property and incrementing the count for the row where the value is stored.
///
/// Overruns are managed via `assert` in debug mode, but that protection goes away in optimized builds.
///
/// This is based on UnsafeMutableArray, which is an unsafe, unmanaged 1-dimensional array.
///
/// **
/// ** ACCESSING ROWS AND COLUMNS
/// **
///
/// Note that the `rowCount` is constant; rows cannot be added. Therefore, the `rowCount` property will always return the row's
/// capacity.
///
/// Each row in the matrix works like an individual UnsafeMutableArray, with each row having a separate count. As elements are
/// added to a row (see `add(toRow:value:)`) the `count` for that row will grow. To access the count for any row, use
/// `colCount(row:)`.
public final class StaticMatrix<T>
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The elements of the matrix
	public private(set) var elements: UnsafeMutablePointer<T>

	/// The column counts for each row in the matrix
	///
	/// Use `colCount(row:)` to access the count for a particular row
	public private(set) var colCounts: UnsafeMutablePointer<Int>

	/// The row capacity of the array; the number of rows that have been allocated for this matrix
	public private(set) var rowCapacity: Int

	/// The column capacity of the array; the number of elements that have been allocated for each row in the matrix
	public private(set) var colCapacity: Int

	/// The total number of elements in the matrix (all elements stored in each row)
	public private(set) var count: Int

	/// Returns a single element in the matrix at the given row and column position
	///
	/// The matrix is accessed via a 2-parameter subscript operator. For example:
	///
	///		let element = myMatrix[rowIndex, colIndex]
	///
	/// The bounds are checked via an `assert` in debug builds. This protection goes away in optimized (release) builds.
	public subscript(row: Int, col: Int) -> T
	{
		get
		{
			assert(row >= 0 && row < rowCapacity)
			assert(col >= 0 && col < colCounts[row])

			return elements[row * colCapacity + col]
		}
		set
		{
			assert(row >= 0 && row < rowCapacity)
			assert(col >= 0 && col < colCounts[row])

			elements[row * colCapacity + col] = newValue
		}
	}

	/// Returns a pointer to the given row at `row`
	///
	/// The bounds are checked via an `assert` in debug builds. This protection goes away in optimized (release) builds.
	public subscript(row: Int) -> UnsafeMutablePointer<T>
	{
		assert(row >= 0 && row < rowCapacity)

		return elements + row * colCapacity
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a matrix with a given `rowCapacity` and `colCapacity` representing the number of elements (of type `T`) that
	/// this matrix can store in each dimension.
	///
	/// After initialization, the `count` property (as well as the individual column counts per row) of this matrix will be 0.
	///
	/// The matrix will not grow automatically, but can be resized via `ensureReservation(newRowCapacity:newColCapacity:)`.
	public init(rowCapacity: Int, colCapacity: Int)
	{
		self.rowCapacity = rowCapacity
		self.colCapacity = colCapacity
		self.count = 0
		self.elements = UnsafeMutablePointer<T>.allocate(capacity: rowCapacity * colCapacity)
		self.colCounts = UnsafeMutablePointer<Int>.allocate(capacity: rowCapacity)

		removeAll()
	}

	/// Returns the number of rows in the matrix
	///
	/// This value will be equivalent to the `rowCapacity` due to the way that the row count is constant (rows cannot be added.)
	/// See the class description for more information.
	@inline(__always) public func rowCount() -> Int
	{
		return rowCapacity
	}

	/// Return the column count for the given `row`
	@inline(__always) public func colCount(row: Int) -> Int
	{
		assert(row >= 0 && row < rowCapacity)
		return colCounts[row]
	}

	/// De-initialize the matrix, freeing any memory currently allocated
	deinit
	{
		free()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Memory management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Clears out the matrix and, if necessary, allocates more memory to meet the `newRowCapacity` and `newColCapacity`
	/// requirements.
	///
	/// You may optionally specify a growth scalar for each dimension (row and/or column), such that if the array needs to grow,
	/// it grows by the new capacities scaled by their respective growth scalar factor.
	///
	/// This method will never reduce the allocation and will only allocate memory if needed. In addition, the matrix will always
	/// be cleared. If you need to reduce the memory allocation, call `free` first.
	@inline(__always) public func ensureReservation(rowCapacity newRowCapacity: Int, colCapacity newColCapacity: Int, rowGrowthScalar: FixedPoint = FixedPoint.kOne, colGrowthScalar: FixedPoint = FixedPoint.kOne)
	{
		if rowCapacity < newRowCapacity || colCapacity < newColCapacity
		{
			free()
			self.rowCapacity = (rowGrowthScalar * newRowCapacity).floor()
			self.colCapacity = (rowGrowthScalar * newColCapacity).floor()
			self.elements = UnsafeMutablePointer<T>.allocate(capacity: rowCapacity * colCapacity)
			self.colCounts = UnsafeMutablePointer<Int>.allocate(capacity: rowCapacity)
		}

		removeAll()
	}

	/// Free all memory allocated by the matrix
	///
	/// It is safe to call this member multiple times; if the matrix has no row or column capacity, this method does nothing other
	/// than to ensure those capacities and `count` are all set to 0.
	@inline(__always) public func free()
	{
		if rowCapacity > 0
		{
			self.colCounts.deallocate()
			if colCapacity > 0
			{
				self.elements.deallocate()
			}
		}
		rowCapacity = 0
		colCapacity = 0
		count = 0
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Element management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Adds a value to the end of the given `toRow` in the matrix
	///
	/// This method is as simple as storing a value at the correct location in the matrix and incrementing the `count` for the
	/// given `toRow`.
	///
	/// You are required to make sure that there is room in the row for the new element. Range checking is asserted in debug mode
	/// but that protection will go away in optimized (release) builds.
	@inline(__always) public func add(toRow row: Int, value: T)
	{
		assert(row >= 0 && row < rowCapacity)
		let colIndex = colCounts[row]
		assert(colIndex >= 0 && colIndex < colCapacity)

		elements[row * colCapacity + colIndex] = value
		colCounts[row] += 1
		count += 1
	}

	/// Fills a matrix with a given value
	///
	/// Every element in the matrix is replaced with the given value. Any data currently stored in the matrix will be overwritten.
	@inline(__always) public func fill(withValue value: T)
	{
		// Count is maximum capacity
		count = colCapacity * rowCapacity

		// Set all the column counts to their capacity & initialize every element to the given value
		colCounts.initialize(repeating: colCapacity, count: rowCapacity)
		elements.initialize(repeating: value, count: count)
	}

	/// Removes the value at index `col` from the given `row` in the matrix by shifting all values after it down by one
	///
	/// You are required to make sure that the `row` and `col` indices are within range. Range checking is asserted in debug mode
	/// but that protection will go away in optimized (release) builds.
	@inline(__always) public func remove(row: Int, col: Int)
	{
		assert(row >= 0 && row < rowCapacity)
		assert(col >= 0 && col < colCapacity)
		assert(colCounts[row] > 0 && colCounts[row] < colCapacity)

		let colCount = colCounts[row] - 1
		count -= 1
		let start = row * colCapacity + col
		let end = start + colCount
		for idx in start..<end
		{
			elements[idx] = elements[idx + 1]
		}

		colCounts[row] = colCount
	}

	/// Removes all value from the given `row` in the matrix
	///
	/// You are required to make sure that the `row` is within range. Range checking is asserted in debug mode but that protection
	/// will go away in optimized (release) builds.
	@inline(__always) public func remove(row: Int)
	{
		assert(row >= 0 && row < rowCapacity)
		count -= colCounts[row]
		colCounts[row] = 0
	}

	/// Empties the matrix
	///
	/// In order to be efficient, the memory for previous elements is left untouched. All this method does is to set the matrix's
	/// `count` property to 0 along with each of the row counts.
	@inline(__always) public func removeAll()
	{
		self.colCounts.initialize(repeating: 0, count: rowCapacity)
		count = 0
	}
}
