//
//  UInt32.swift
//  Minion
//
//  Created by Paul Nettle on 2/5/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Printing helper for binary values
// ---------------------------------------------------------------------------------------------------------------------------------

public extension UInt32
{
	/// Converts the value to a string with optional width, zero-padding and sign specifications. Note that the zero-padding flag
	/// is ignored if `width` is not specified.
	func toString(_ width: Int = -1, zero: Bool = false) -> String
	{
		let prec = width == -1 ? "" : (zero ? "0\(width)" : "\(width)")
		return String(format: "%\(prec)d", arguments: [self])
	}

	/// Returns a value printed in boolean (0b0011011) with an optional specification as to the number of (least significant) bits
	/// to display.
	///
	/// The `reversed` flag can be used to optionally reverse the order that bits are output
	func binaryString(_ maxBits: Int = MemoryLayout<UInt32>.size * 8, reversed: Bool = false) -> String
	{
		assert(maxBits >= 0 && maxBits <= MemoryLayout<UInt32>.size * 8)
		var str = "0b"
		for i in 0..<maxBits
		{
			let shiftAmount = UInt32(reversed ? i : maxBits - 1 - i)
			str += ((self >> shiftAmount) & 1) == 1 ? "1":"0"
		}
		return str
	}

	/// Returns a value printed in boolean (--xx-xx) with an optional specification as to the number of (least significant) bits
	/// to display.
	///
	/// The `reversed` flag can be used to optionally reverse the order that bits are output
	func binaryStringAscii(_ maxBits: Int = MemoryLayout<UInt32>.size * 8, reversed: Bool = false) -> String
	{
		assert(maxBits >= 0 && maxBits <= MemoryLayout<UInt32>.size * 8)
		var str = ""
		for i in 0..<maxBits
		{
			let shiftAmount = UInt32(reversed ? i : maxBits - 1 - i)
			str += ((self >> shiftAmount) & 1) == 1 ? "x":"-"
		}
		return str
	}

	/// Returns a dot-notation string representation of an IP address
	///
	/// The value is expected to be in host-byte-order
	func toIPAddress() -> String
	{
		// Convert (if necessary) to a known byte order so we know the order of the octets
		let addr = bigEndian

		let octet0 = (addr >>  0) & 0xff
		let octet1 = (addr >>  8) & 0xff
		let octet2 = (addr >> 16) & 0xff
		let octet3 = (addr >> 24) & 0xff
		return "\(octet0).\(octet1).\(octet2).\(octet3)"
	}
}
