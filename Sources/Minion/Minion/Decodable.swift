//
//  Decodable.swift
//  Minion
//
//  Created by Paul Nettle on 2/4/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// Decodable protocol provides a means for objects and/or values to decode their contents from a `Data` instance
public protocol Decodable
{
	/// Decode self by moving through a `Data` instance
	///
	/// The `consumed` parameter should be updated to reflect the bytes consumed by the decode
	///
	/// Implementations should be careful to account for Endianness
	///
	/// Returns true on success, otherwise false
	static func decode(from: Data, consumed: inout Int) -> Self?

	/// Decode self by moving through a `Data` instance
	///
	/// This is a convenience function that removes the need for the caller to create a `consumed` parameter
	///
	/// Implementations should be careful to account for Endianness
	///
	/// Returns true on success, otherwise false
	static func decode(from: Data) -> Self?
}

/// Default implementations for Decodable types
public extension Decodable
{
	/// Decode self by moving through a `Data` instance
	///
	/// The `consumed` parameter is updated to reflect the bytes consumed by the decode
	///
	/// Note: This provides non-endian corrected data. Endian-corrected decoding is provided in an extension to the
	/// `FixedWidthInteger` protocol, which represents integer values that require endian correction.
	///
	/// Returns true on success, otherwise false
	static func decode(from data: Data, consumed: inout Int) -> Self?
	{
		let offset = consumed
		consumed += MemoryLayout<Self>.size

		assert(consumed <= data.count)
		if consumed > data.count { return nil }

		return data.withUnsafeBytes
		{ src in
			let ptr = src.baseAddress!.assumingMemoryBound(to: UInt8.self)
			return (ptr + offset).withMemoryRebound(to: self, capacity: 1) { $0.pointee }
		}
	}

	/// Decode self by moving through a `Data` instance
	///
	/// This is a convenience function that removes the need for the caller to create a `consumed` parameter
	///
	/// Upon completion, the amount of data consumed is verified with the length of the data, therefore it is important that the
	/// input `data` contain exactly one encoded instance of the object being decoded.
	///
	/// Returns true on success, otherwise false
	static func decode(from data: Data) -> Self?
	{
		var consumed: Int = 0
		guard let result = Self.decode(from: data, consumed: &consumed) else { return nil }

		assert(consumed == data.count)
		if consumed != data.count
		{
			gLogger.error("Corrupt decode - consumed \(consumed) out of \(data.count)")
			return nil
		}

		return result
	}
}

/// Default implementations of Decodable for FixedWidthInteger types in order to correct for Endianness
extension FixedWidthInteger where Self: Decodable
{
	/// Decode self by moving through a `Data` instance
	///
	/// The `consumed` parameter is updated to reflect the bytes consumed by the decode
	///
	/// Note: This is a custom implementation to manage endian corrected data on `FixedWidthInteger` types
	///
	/// Returns true on success, otherwise false
	public static func decode(from data: Data, consumed: inout Int) -> Self?
	{
		let offset = consumed
		consumed += MemoryLayout<Self>.size

		assert(consumed <= data.count)
		if consumed > data.count { return nil }

		return data.withUnsafeBytes
		{ src in
			let ptr = src.baseAddress!.assumingMemoryBound(to: UInt8.self)
			return (ptr + offset).withMemoryRebound(to: Self.self, capacity: 1)
			{
				Self(bigEndian: $0.pointee)
			}
		}
	}
}

// Associate the Decodable protocol to the specific types of `FixedWidthInteger`
extension Bool: Decodable {}
extension Int: Decodable {}
extension UInt: Decodable {}
extension Int8: Decodable {}
extension UInt8: Decodable {}
extension Int16: Decodable {}
extension UInt16: Decodable {}
extension Int32: Decodable {}
extension UInt32: Decodable {}
extension Int64: Decodable {}
extension UInt64: Decodable {}

extension Float: Decodable
{
	/// Custom decoding of `Float` to handle endian correction
	public static func decode(from data: Data, consumed: inout Int) -> Float?
	{
		let offset = consumed
		consumed += MemoryLayout<Float>.size

		assert(consumed <= data.count)
		if consumed > data.count { return nil }

		return data.withUnsafeBytes
		{ src in
			// We use a 32-bit integer to perform endian conversion
			let ptr = src.baseAddress!.assumingMemoryBound(to: UInt8.self)
			var val32 = (ptr + offset).withMemoryRebound(to: UInt32.self, capacity: 1) { UInt32(bigEndian: $0.pointee) }
			return withUnsafePointer(to: &val32)
			{
				$0.withMemoryRebound(to: Float.self, capacity: 1) { $0.pointee }
			}
		}
	}
}

extension Double: Decodable
{
	/// Custom decoding of `Double` to handle endian correction
	public static func decode(from data: Data, consumed: inout Int) -> Double?
	{
		let offset = consumed
		consumed += MemoryLayout<Double>.size

		assert(consumed <= data.count)
		if consumed > data.count { return nil }

		return data.withUnsafeBytes
		{ src in
			// We use a 64-bit integer to perform endian conversion
			let ptr = src.baseAddress!.assumingMemoryBound(to: UInt8.self)
			var val64 = (ptr + offset).withMemoryRebound(to: UInt64.self, capacity: 1) { UInt64(bigEndian: $0.pointee) }
			return withUnsafePointer(to: &val64)
			{
				$0.withMemoryRebound(to: Double.self, capacity: 1) { $0.pointee }
			}
		}
	}
}

extension String: Decodable
{
	/// Custom decoding of `String` to decode through a `data` object
	public static func decode(from data: Data, consumed: inout Int) -> String?
	{
		guard let subset = Data.decode(from: data, consumed: &consumed) else { return nil }
		return String(data: subset, encoding: .utf8)
	}
}

extension Array: Decodable
{
	/// Prevent from attempting to decode `Arrays` that do not contain `Decodable` elements
	public static func decode(from data: Data, consumed: inout Int) -> Array?
	{
		gLogger.error("Unsupported array element type for decode")
		return nil
	}
}

extension Array where Element: Decodable
{
	/// Custom decoding of an `Array` of `Decodable` elements
	public static func decode(from data: Data, consumed: inout Int) -> [Element]?
	{
		guard let subset = Data.decode(from: data, consumed: &consumed) else { return nil }
		return subset.toArray(type: Element.self)
	}
}

extension Dictionary where Key: Decodable, Value: Decodable
{
	/// Custom decoding of a `Dictionary` of `Decodable` key/value pairs
	public static func decode(from data: Data, consumed: inout Int) -> [Key: Value]?
	{
		guard let count = UInt16.decode(from: data, consumed: &consumed) else { return nil }

		var result = [Key: Value]()
		for _ in 0..<count
		{
			guard let key = Key.decode(from: data, consumed: &consumed) else { return nil }
			guard let value = Value.decode(from: data, consumed: &consumed) else { return nil }
			result[key] = value
		}
		return result
	}
}

extension Data: Decodable
{
	/// Custom decoding of `Data`
	public static func decode(from data: Data, consumed: inout Int) -> Data?
	{
		// Extract the count
		guard let byteCount = UInt16.decode(from: data, consumed: &consumed) else { return nil }

		// Extract the data of `byteCount` bytes
		let start = data.startIndex.advanced(by: consumed)
		let end = data.startIndex.advanced(by: consumed + Int(byteCount))
		let range = Range<Data.Index>(uncheckedBounds: (lower: start, upper: end))
		consumed += Int(byteCount)
		return data.subdata(in: range)
	}
}
