//
//  Encodable.swift
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
import Swift

/// `Encodable` protocol provides a means for objects and/or values to encode their contents into a `Data` instance
public protocol Encodable
{
	/// Encode self by appending to a `Data` instance
	///
	/// Implementations should be careful to account for Endianness
	///
	/// Returns true on success, otherwise false
	func encode(into: inout Data) -> Bool

	/// Convenience function to encode into a `Data` instance
	///
	/// Implementations should be careful to account for Endianness
	///
	/// Returns the data of the encoded object(s), otherwise `nil`
	func encode() -> Data?
}

/// Default conformance for `Encodable` types
public extension Encodable
{
	/// Encode self by appending to a `Data` instance
	///
	/// Note: This provides non-endian corrected data. Endian-corrected encoding is provided in an extension to the
	/// `FixedWidthInteger` protocol, which represents integer values that require endian correction.
	///
	/// For other multi-byte values that require endian correctness (such as `Float` and `Double`), custom implementations have
	/// been created (see their appropriate extensions further down in this file.)
	///
	/// Returns true on success, otherwise false
	func encode(into data: inout Data) -> Bool
	{
		assert(data.count + MemoryLayout<Self>.size <= Int(UInt16.max))
		if data.count + MemoryLayout<Self>.size > Int(UInt16.max) { return false }

		var tmp = self
		withUnsafePointer(to: &tmp) { data.append(UnsafeBufferPointer(start: $0, count: 1)) }
		return true
	}

	/// Convenience function to encode into a `Data` Instance
	///
	/// Returns the data of the encoded object(s), otherwise `nil`
	func encode() -> Data?
	{
		// We can quickly calculate the minimum capacity needed (things like String and Data could have much higher memory
		// requirements than their layouts in memory), but it's a cheap head start to reduce re-allocations as we encode
		let minCapacity = MemoryLayout.size(ofValue: self)

		var data = Data(capacity: minCapacity)
		if !encode(into: &data) { return nil }
		return data
	}
}

/// Default implementations of Decodable for FixedWidthInteger types in order to correct for Endianness
extension FixedWidthInteger where Self: Encodable
{
	/// Default implementation of Encodable for FixedWidthInteger types in order to correct for Endianness
	public func encode(into data: inout Data) -> Bool
	{
		assert(data.count + MemoryLayout<Self>.size <= Int(UInt16.max))
		if data.count + MemoryLayout<Self>.size > Int(UInt16.max) { return false }

		var tmp = self.bigEndian
		withUnsafePointer(to: &tmp) { data.append(UnsafeBufferPointer(start: $0, count: 1)) }
		return true
	}
}

// Associate the Encodable protocol to the specific types of `FixedWidthInteger`
extension Bool: Encodable {}
extension Int: Encodable {}
extension UInt: Encodable {}
extension Int8: Encodable {}
extension UInt8: Encodable {}
extension Int16: Encodable {}
extension UInt16: Encodable {}
extension Int32: Encodable {}
extension UInt32: Encodable {}
extension Int64: Encodable {}
extension UInt64: Encodable {}

extension Float: Encodable
{
	/// Custom encoding of `Float` to handle endian correction
	public func encode(into data: inout Data) -> Bool
	{
		assert(data.count + MemoryLayout.size(ofValue: self) <= Int(UInt16.max))
		if data.count + MemoryLayout.size(ofValue: self) > Int(UInt16.max) { return false }

		var tmp = self
		if 1 != 1.bigEndian
		{
			withUnsafeMutableBytes(of: &tmp)
			{
				swap(&$0[0], &$0[3])
				swap(&$0[1], &$0[2])
			}
		}
		withUnsafePointer(to: &tmp) { data.append(UnsafeBufferPointer(start: $0, count: 1)) }
		return true
	}
}

extension Double: Encodable
{
	/// Custom encoding of `Double` to handle endian correction
	public func encode(into data: inout Data) -> Bool
	{
		assert(data.count + MemoryLayout.size(ofValue: self) <= Int(UInt16.max))
		if data.count + MemoryLayout.size(ofValue: self) > Int(UInt16.max) { return false }

		var tmp = self
		if 1 != 1.bigEndian
		{
			withUnsafeMutableBytes(of: &tmp)
			{
				swap(&$0[0], &$0[7])
				swap(&$0[1], &$0[6])
				swap(&$0[2], &$0[5])
				swap(&$0[3], &$0[4])
			}
		}
		withUnsafePointer(to: &tmp) { data.append(UnsafeBufferPointer(start: $0, count: 1)) }
		return true
	}
}

extension String: Encodable
{
	/// Custom encoding of `String` to encode through a `data` object
	public func encode(into data: inout Data) -> Bool
	{
		return self.data.encode(into: &data)
	}
}

extension Array: Encodable
{
	/// Prevent from attempting to encode `Array`s that do not contain `Encodable` elements
	public static func encode(from data: Data, consumed: inout Int) -> Array?
	{
		gLogger.error("Unsupported array element type for encode")
		return nil
	}
}

extension Array where Element: Encodable
{
	/// Custom encoding of an `Array` of `Encodable` elements
	public func encode(into dest: inout Data) -> Bool
	{
		let bytes = count * MemoryLayout<Element>.size
		assert(bytes <= Int(UInt16.max))
		if bytes > Int(UInt16.max) { return false }

		// Encode the length
		if !UInt16(bytes).encode(into: &dest) { return false }
		for val in self
		{
			if !val.encode(into: &dest) { return false }
		}

		return true
	}
}

extension Dictionary: Encodable
{
	/// Prevent from attempting to encode `Dictionary`s that do not contain `Encodable` elements
	public static func encode(from data: Data, consumed: inout Int) -> Dictionary?
	{
		gLogger.error("Unsupported dictionary Key:Value types for encode")
		return nil
	}
}

extension Dictionary where Key: Encodable, Value: Encodable
{
	/// Custom encoding of a `Dictionary` of `Encodable` elements
	public func encode(into dest: inout Data) -> Bool
	{
		// Encode the count
		if !UInt16(count).encode(into: &dest) { return false }
		for key in keys
		{
			if !key.encode(into: &dest) { return false }
			if !(self[key]?.encode(into: &dest) ?? false) { return false }
		}

		return true
	}
}

extension Data: Encodable
{
	/// Custom encoding of `Data`
	public func encode(into data: inout Data) -> Bool
	{
		assert(count <= Int(UInt16.max))
		if count > Int(UInt16.max) { return false }

		if !UInt16(count).encode(into: &data) { return false }
		data.append(self)
		return true
	}
}
