//
//  Data.swift
//  Minion
//
//  Created by Paul Nettle on 3/20/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

// ---------------------------------------------------------------------------------------------------------------------------------
// Image type conversion
// ---------------------------------------------------------------------------------------------------------------------------------

public extension Data
{
#if os(macOS) || os(iOS)
	func toCGImage(width: Int, height: Int, bytesPerPixel: Int = 4) -> CGImage?
	{
		if let provider = CGDataProvider(data: self as CFData)
		{
			let bitmapInfo = bytesPerPixel == 1 ?
				CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue) :
				CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
			return CGImage(width: width,
			               height: height,
			               bitsPerComponent: 8,
			               bitsPerPixel: bytesPerPixel * 8,
			               bytesPerRow: width * bytesPerPixel,
						   space: bytesPerPixel == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB(),
			               bitmapInfo: bitmapInfo,
			               provider: provider,
			               decode: nil,
			               shouldInterpolate: false,
			               intent: CGColorRenderingIntent.defaultIntent)
		}

		return nil
	}
#endif

#if os(macOS)
	func toNSImage(width: Int, height: Int, bytesPerPixel: Int) -> NSImage?
	{
		if let cgImage = toCGImage(width: width, height: height, bytesPerPixel: bytesPerPixel)
		{
			return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
		}
		return nil
	}

	var bitmap: NSBitmapImageRep?
	{
		return NSBitmapImageRep(data: self)
	}
#endif
}

// ---------------------------------------------------------------------------------------------------------------------------------
// File manipulation
// ---------------------------------------------------------------------------------------------------------------------------------

public extension Data
{
	func appendToFile(fileUrl: URL) throws
	{
		if let fileHandle = FileHandle(forWritingAtPath: fileUrl.path)
		{
			defer { fileHandle.closeFile() }
			_ = fileHandle.seekToEndOfFile()
			fileHandle.write(self)
		}
		else
		{
			try write(to: fileUrl, options: .atomic)
		}
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Using Data as a storage container for built-in types
// ---------------------------------------------------------------------------------------------------------------------------------

public protocol DataConvertible
{
	static func + (lhs: Data, rhs: Self) -> Data
	static func += (lhs: inout Data, rhs: Self)
}

public extension DataConvertible
{
//	init?(data: Data)
//	{
//		guard data.count == MemoryLayout<Self>.size else { return nil }
//		self = data.withUnsafeBytes { $0.pointee }
//	}

	var data: Data
	{
		var value = self
		return withUnsafePointer(to: &value) { Data(buffer: UnsafeBufferPointer(start: $0, count: 1)) }
	}

	static func + (lhs: Data, rhs: Self) -> Data
	{
		var value = rhs
		let data = withUnsafePointer(to: &value) { Data(buffer: UnsafeBufferPointer(start: $0, count: 1)) }
		return lhs + data
	}

	static func += (lhs: inout Data, rhs: Self)
	{
		// swiftlint:disable shorthand_operator
		lhs = lhs + rhs
		// swiftlint:enable shorthand_operator
	}
}

public extension Data
{
	init<T>(from value: T)
	{
		var value = value
		self.init()
		withUnsafePointer(to: &value) { self.append(UnsafeBufferPointer(start: $0, count: 1)) }
	}

	func to<T>(type: T.Type) -> T
	{
		return self.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: type).pointee }
	}

	init<T>(fromArray values: [T])
	{
		self.init()
		values.withUnsafeBufferPointer
		{
			self.append($0)
		}
	}

	func toArray<T>(type: T.Type) -> [T]
	{
		return self.withUnsafeBytes {
			let ptr = $0.baseAddress!.assumingMemoryBound(to: type)
			return [T](UnsafeBufferPointer(start: ptr, count: self.count/MemoryLayout<T>.stride)) }
	}

	func hexDump(prefix: String = "", width: Int = 16) -> String
	{
		var result = ""
		if count == 0 { return result }

		let bytes = toArray(type: UInt8.self)
		var bytesProcessed = 0

		while bytesProcessed < count
		{
			let adrPart = String(format: "%04X: ", bytesProcessed)

			var hexPart = ""
			hexPart.reserveCapacity(width * 3)

			var ascPart = ""
			hexPart.reserveCapacity(width)

			let lineLen = Swift.min(width, count - bytesProcessed)

			for i in 0..<lineLen
			{
				let byte = bytes[bytesProcessed + i]
				hexPart += String(format: "%02X ", byte)
				ascPart += byte > 31 && byte < 127 ? String(format: "%c", byte) : "."
			}

			for _ in lineLen..<width
			{
				hexPart += ".. "
				ascPart += " "
			}

			result += prefix + adrPart + hexPart + ascPart + String.kNewLine

			bytesProcessed += lineLen
		}

		return result
	}

	func asciiByteString() -> String
	{
		var result = ""
		if count == 0
		{
			return result
		}

		let bytes = toArray(type: UInt8.self)
		result.reserveCapacity(bytes.count * 3)

		for byte in bytes
		{
			if byte > 31 && byte < 127
			{
				result += String(format: "%c", byte)
			}
			else
			{
				result += String(format: "\\x%02X", byte)
			}
		}
		return result.trimmingCharacters(in: [" "])
	}

	func hexaByteString(withSpaces: Bool = true) -> String
	{
		var result = ""
		if count == 0
		{
			return result
		}

		let bytes = toArray(type: UInt8.self)
		result.reserveCapacity(bytes.count * 3)

		for byte in bytes
		{
			if byte > 31 && byte < 127
			{
				result += String(format: "%c\(withSpaces ? " ":"")", byte)
			}
			else
			{
				result += ".\(withSpaces ? " ":"")"
			}
			result += String(format: "(%02X)\(withSpaces ? " ":"")", byte)
		}
		return result.trimmingCharacters(in: [" "])
	}

	func hexByteString(withSpaces: Bool = true) -> String
	{
		var result = ""
		if count == 0 { return result }

		let bytes = toArray(type: UInt8.self)
		result.reserveCapacity(bytes.count * 3)

		for byte in bytes
		{
			result += String(format: "%02X\(withSpaces ? " ":"")", byte)
		}
		return result.trimmingCharacters(in: [" "])
	}
}

// ! NOTE !
//
// `Int` is intentionally not included here as it is platform-dependent. Sure, so is the endianness, but at least we are avoiding
// reading the file from wrong offsets by reading the wrong number of bytes.

extension Int8: DataConvertible { }
extension Int16: DataConvertible { }
extension Int32: DataConvertible { }
extension Int64: DataConvertible { }
extension UInt8: DataConvertible { }
extension UInt16: DataConvertible { }
extension UInt32: DataConvertible { }
extension UInt64: DataConvertible { }
extension Float: DataConvertible { }
extension Double: DataConvertible { }

extension String: DataConvertible
{
	public init?(data: Data)
	{
		self.init(data: data, encoding: .utf8)
	}

	public var data: Data
	{
		// Note: a conversion to UTF-8 cannot fail.
		return self.data(using: .utf8)!
	}

	public static func + (lhs: Data, rhs: String) -> Data
	{
		guard let data = rhs.data(using: .utf8) else { return lhs }
		return lhs + data
	}
}

extension Data: DataConvertible
{
	public static func + (lhs: Data, rhs: Data) -> Data
	{
		var data = Data()
		data.append(lhs)
		data.append(rhs)
		return data
	}
}
