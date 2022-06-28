//
//  Array.swift
//  Minion
//
//  Created by Paul Nettle on 3/22/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// Custom Array extension for arrays of Strings
public extension Array where Element == String
{
	/// Returns the maximum length of any string in the collection
	func maxLength(startValue: Int = 0) -> Int
	{
		return self.reduce(startValue) { Swift.max($0, $1.length()) }
	}

	/// Produces an Array of Strings (normalized such that they all have the same length) from the collection beginning with a
	/// `header` line, a separator line and then all data rows. In addition, every row in the array is prefixed with `prefix`.
	///
	func columnize(prefix: String = "", header: String = "") -> [String]
	{
		// Populate an empty result (including two rows for the header and spacer)
		var result = [String](repeating: prefix, count: count + 2)

		// Find the max length of all columns (including the header)
		let columnWidth = maxLength(startValue: header.length()) + 1

		// Add the header
		result[0] += header.padding(toLength: columnWidth, withPad: " ", startingAt: 0)

		// Add the spacer
		result[1] += String(repeating: "-", count: columnWidth)

		// Add the data rows
		var resultIndex = 2
		for str in self
		{
			result[resultIndex] += str.padding(toLength: columnWidth, withPad: " ", startingAt: 0)
			resultIndex += 1
		}

		return result
	}

	/// Returns an Array of Strings with all rows in `other` added to the end of the strings in this collection.
	///
	/// No additional padding is added and the columns are assumed to already be columnized (see `columnize()`).
	///
	/// Note that the number of elements in `other` is NOT allowed to be greater than the count in this collection. If `other`'s
	/// count is less than this collection's count, then padding will be added to the remainder in order to maintain consistent
	/// columnar output for future columns.
	func concatRows(with other: [String]) -> [String]
	{
		assert(other.count <= count)

		var result = [String](self)
		var resultIndex = 0
		for str in other
		{
			result[resultIndex] += str
			resultIndex += 1
		}

		// Fill in any leftover rows
		let blank = String(repeating: " ", count: other[0].length())
		while resultIndex < count
		{
			result[resultIndex] += blank
			resultIndex += 1
		}

		return result
	}

	/// Returns an Array of Strings in which `inRows` is first columnized, and then concatenated onto this collection's rows of
	/// data.
	func addColumn(with inRows: [String], prefix: String = "", header: String = "") -> [String]
	{
		let newColumn = inRows.columnize(prefix: prefix, header: header)
		return concatRows(with: newColumn)
	}
}

/// Custom Array extension for arrays of bytes (UInt8)
public extension Array where Element == UInt8
{
	/// Removes a UTF8 string from the front of the array
	///
	/// The string is not null-terminated and must be preceeded by a UInt16 of the number of UTF8 bytes
	mutating func popFrontUTF8String() -> String
	{
		var length = Int(popFrontUInt16())
		if length > count { length = count }

		// Get a null-terminated C string
		var cString = [Int8](repeating: 0, count: length+1)
		self.withUnsafeBytes
		{
			if let ptr = $0.baseAddress?.assumingMemoryBound(to: Int8.self)
			{
				for i in 0..<length
				{
					cString[i] = ptr[i]
				}
			}
		}

		// Clean up the array
		removeFirst(length)

		return String(utf8String: cString)!
	}

	/// Removes the first byte from the array, returns the removed byte as a UInt8
	mutating func popFrontUInt8() -> UInt8
	{
		let result: UInt8 = self[0]
		removeFirst(1)
		return result
	}

	/// Removes the first two bytes from the array, returns the removed bytes as a UInt16
	///
	/// The bytes are read in MSB->LSB order (with the first byte being the highest 8 bits of the result)
	mutating func popFrontUInt16() -> UInt16
	{
		var result: UInt16 = 0
		result |= (UInt16(self[0]) << 8)
		result |= (UInt16(self[1]) << 0)
		removeFirst(2)
		return result
	}

	/// Removes the first four bytes from the array, returns the removed bytes as a UInt32
	///
	/// The bytes are read in MSB->LSB order (with the first byte being the highest 8 bits of the result)
	mutating func popFrontUInt32() -> UInt32
	{
		var result: UInt32 = 0
		result |= (UInt32(self[0]) << 24)
		result |= (UInt32(self[1]) << 16)
		result |= (UInt32(self[2]) <<  8)
		result |= (UInt32(self[3]) <<  0)
		removeFirst(4)
		return result
	}

	/// Removes the first eight bytes from the array, returns the removed bytes as a UInt64
	///
	/// The bytes are read in MSB->LSB order (with the first byte being the highest 8 bits of the result)
	mutating func popFrontUInt64() -> UInt64
	{
		var result: UInt64 = 0
		result |= (UInt64(self[0]) << 56)
		result |= (UInt64(self[1]) << 48)
		result |= (UInt64(self[2]) << 40)
		result |= (UInt64(self[3]) << 32)
		result |= (UInt64(self[4]) << 24)
		result |= (UInt64(self[5]) << 16)
		result |= (UInt64(self[6]) <<  8)
		result |= (UInt64(self[7]) <<  0)
		removeFirst(8)
		return result
	}

	/// Appends a 16-bit count followed by the bytes of a UTF8 string to the end of the array
	mutating func pushBack(_ value: String)
	{
		let byteCount = value.lengthOfBytes(using: .utf8)
		pushBack(UInt16(byteCount))

		let bytes = value.utf8CString
		for i in 0..<byteCount
		{
			append(UInt8(bytes[i]))
		}
	}

	/// Appends a UInt8 to the end of the array
	mutating func pushBack(_ value: UInt8)
	{
		append(value)
	}

	/// Appends a UInt16 to the end of the array
	///
	/// The bytes are appended in in MSB->LSB order (with the first byte being the highest 8 bits of the result)
	mutating func pushBack(_ value: UInt16)
	{
		append(UInt8((value >>  8) & 0xff))
		append(UInt8((value >>  0) & 0xff))
	}

	/// Appends a UInt32 to the end of the array
	///
	/// The bytes are appended in in MSB->LSB order (with the first byte being the highest 8 bits of the result)
	mutating func pushBack(_ value: UInt32)
	{
		append(UInt8((value >> 24) & 0xff))
		append(UInt8((value >> 16) & 0xff))
		append(UInt8((value >>  8) & 0xff))
		append(UInt8((value >>  0) & 0xff))
	}

	/// Appends a UInt64 to the end of the array
	///
	/// The bytes are appended in in MSB->LSB order (with the first byte being the highest 8 bits of the result)
	mutating func pushBack(_ value: UInt64)
	{
		append(UInt8((value >> 56) & 0xff))
		append(UInt8((value >> 48) & 0xff))
		append(UInt8((value >> 40) & 0xff))
		append(UInt8((value >> 32) & 0xff))
		append(UInt8((value >> 24) & 0xff))
		append(UInt8((value >> 16) & 0xff))
		append(UInt8((value >>  8) & 0xff))
		append(UInt8((value >>  0) & 0xff))
	}
}
