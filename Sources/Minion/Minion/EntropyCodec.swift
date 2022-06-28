//
//  EntropyCodec.swift
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

/// Entropy encryption. This code provides only a moderate level of obfuscation.
///
/// This encryption utilizes advanced XOR technology, providing an encryption that is completely reversable using the same method
/// to decrypt as was used to encrypt. Yes, that was sarcasm (but no less true.)
///
/// We use an entropy table (256 random values) and xor those values over the data, allowing the table to repeat (wrapping the
/// index) as needed to re-use entropy data until we have processed all of the data.
///
/// To improve obfuscation, we include an entropy seed which acts as an initial index into the table for the starting point as we
/// begin the decryption process.
internal struct EntropyCodec: CodecProvider
{
	/// Entropy table - just random values
	///
	/// The length of this table must be an even power of two. This is needed for efficient encryption by allowing us to mask our
	/// index value by `kTableIndexMask`, which is one less than the size of this table.
	private static let kEntropyTable: [UInt8] =
	[
		0x39, 0xab, 0x1c, 0x5e, 0x5b, 0x56, 0xc2, 0x59, 0xf1, 0x11, 0xf1, 0x92, 0x82, 0xa4, 0x3f, 0xd5,
		0x72, 0xc1, 0x9b, 0xf1, 0x74, 0xbe, 0x5d, 0x80, 0xde, 0xb1, 0xfe, 0x9b, 0x06, 0xa7, 0xdc, 0x74,
		0x2d, 0x76, 0xf9, 0x88, 0x6f, 0xe9, 0x2c, 0x4a, 0x74, 0x84, 0xaa, 0x5c, 0xa9, 0xdc, 0xb0, 0xda,
		0xc6, 0x14, 0x29, 0x29, 0xf3, 0xe0, 0x0b, 0xd5, 0xa7, 0x91, 0x47, 0x06, 0x63, 0x51, 0xca, 0x67,
		0x65, 0x92, 0x72, 0x2c, 0x54, 0x0a, 0x73, 0x76, 0x6a, 0x0a, 0xbb, 0x81, 0xc9, 0x2e, 0xc2, 0x85,
		0xd1, 0x10, 0x6a, 0xa0, 0x19, 0x92, 0xe8, 0xd6, 0x99, 0x06, 0x24, 0xf4, 0x35, 0x85, 0x0e, 0x70,
		0x39, 0x68, 0x2e, 0x6f, 0xb3, 0x1c, 0x0c, 0x4e, 0xd8, 0xaa, 0x4a, 0x5b, 0xca, 0x4f, 0x9c, 0xf3,
		0x90, 0xc6, 0x71, 0x78, 0xfa, 0xbe, 0xff, 0xa4, 0x50, 0x6c, 0xeb, 0xbe, 0xa3, 0xf7, 0xf9, 0xf2,
		0x42, 0xe9, 0xb5, 0xdb, 0x98, 0x8a, 0x2f, 0x71, 0x37, 0x44, 0x91, 0xb5, 0xfb, 0xcf, 0xc0, 0xa5,
		0xd8, 0x55, 0x0c, 0x7d, 0x98, 0x07, 0xaa, 0x12, 0x83, 0x5b, 0x01, 0x24, 0x85, 0xbe, 0x31, 0xc3,
		0xe4, 0x24, 0x0c, 0xa1, 0xc1, 0x9b, 0x69, 0xef, 0xbe, 0x47, 0x86, 0x0f, 0x9d, 0xc6, 0xc1, 0xcc,
		0x98, 0xbf, 0x59, 0x7f, 0x52, 0x3e, 0x51, 0xa8, 0x31, 0xc6, 0x6d, 0xb0, 0x27, 0xc8, 0x03, 0xc7,
		0x27, 0x53, 0x38, 0x0d, 0x85, 0xb7, 0x0a, 0x2e, 0x1b, 0x21, 0x38, 0x4d, 0x6d, 0xfc, 0x2c, 0x13,
		0xa2, 0xc7, 0x6c, 0x51, 0xa1, 0xbf, 0xe8, 0xa8, 0x1a, 0x66, 0x4b, 0xc2, 0x8b, 0x70, 0x4b, 0xa3,
		0x19, 0x34, 0xb0, 0xbc, 0x16, 0xa4, 0xc1, 0x1e, 0x37, 0x6c, 0x08, 0x27, 0x77, 0x4c, 0x48, 0xb5,
		0x74, 0x8c, 0xc7, 0x02, 0xee, 0x8f, 0x82, 0x78, 0xa5, 0x63, 0x6f, 0x84, 0x78, 0x14, 0xc8, 0x08
	]

	/// The mask we use for efficient index wrapping used during encryption and decryption. See `kEntropyTable` for more details.
	private static let kTableIndexMask = kEntropyTable.count - 1

 	/// Returns the name of this codec
	public static var name: String { return "Entropy" }

	/// Returns the EncryptionAlgorithm
	public static var algorithm: EncryptionAlgorithm { return .Entropy }

	/// Entropy seed, used as the starting table offset
	private var entropySeed: UInt8

	/// Initialize the codec
	public init()
	{
		self.entropySeed = UInt8(Random.value() & 0xff)
	}

	/// Encrypt `data` using Entropy encoding
	public func encrypt(_ data: Data) -> Data
	{
		// Ensure our kEntropyTable length exactly 256
		//
		// Specifically, it must be a power of two and the largest index must not be larger than what a UInt8 can store
		assert(EntropyCodec.kEntropyTable.count == 0x100)

		let count = data.count
		var result = Data(count: count)
		let seed = Int(entropySeed)

		EntropyCodec.kEntropyTable.withUnsafeBytes
		{ (table: UnsafeRawBufferPointer) -> Void in
			result.withUnsafeMutableBytes
			{
				(dst: UnsafeMutableRawBufferPointer) -> Void in
				data.withUnsafeBytes
				{
					(src: UnsafeRawBufferPointer) -> Void in

					for i in 0..<count
					{
						dst[i] = src[i] ^ table[(i + seed) % EntropyCodec.kTableIndexMask]
					}
				}
			}
		}
		return result
	}

	/// Decrypt `data` using Entropy encoding
	public func decrypt(_ data: Data) -> Data
	{
		// Our encryption uses an xor, so assuming our data is properly encrypted, we can simply encrypt again to decrypt
		return encrypt(data)
	}

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !EntropyCodec.algorithm.rawValue.encode(into: &data) { return false }
		if !entropySeed.encode(into: &data) { return false }
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> EntropyCodec?
	{
		guard let rawAlgorithm = UInt8.decode(from: data, consumed: &consumed) else { return nil }
		guard let entropySeed = UInt8.decode(from: data, consumed: &consumed) else { return nil }

		// Verify the algorithm matches
		guard let algorithm = EncryptionAlgorithm(rawValue: rawAlgorithm) else { return nil }
		if algorithm != self.algorithm { return nil }

		var result = EntropyCodec()
		result.entropySeed = entropySeed
		return result
	}
}
