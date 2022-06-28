//
//  Sha256.swift
//  Minion
//
//  Created by Paul Nettle on 1/30/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// Native implementation of the SHA256 hash algorithm for Swift.
///
/// Specification: http://csrc.nist.gov/publications/fips/fips180-2/fips180-2withchangenotice.pdf
///
/// For one-shot hashing (i.e., hashing a string or preconstructed data) simply use the `generate(...)` method. There are a few
/// variants of this method that provide hashing for various types of input data including String, Data, UnafePointer<UInt8>,
/// UnsafeRawPointer (and more.)
///
///     // Hash a string
///     let hash: Sha256.Hash = Sha256(fromUtf8String: "My secret is a secret")
///
/// If you plan to generate a number of hashes or you want to construct your hash via parts of data (from a stream or from multiple
/// input types), use the create-add-finalize pattern, like so:
///
/// Usage follows this pattern:
///
///     let hasher = Sha256()
///     let inputString: String = ...
///     let inputData: Data = ...
///
///     hasher.add(utf8String: inputString)
///     hasher.add(data: inputData)
///     let hash: Sha256.Hash = hasher.finalize()
///
///     //
///     // Optionally call `reset` if you plan to re-use the object to generate more hashes
///     //
///
///     let hash: Sha256.Hash = hasher.finalize()
///
///     // If you plan to re-use this instance, reset it before adding more data
///     hasher.reset()
public class Sha256
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Types
	// -----------------------------------------------------------------------------------------------------------------------------

	public typealias Hash = [UInt8]

	// -----------------------------------------------------------------------------------------------------------------------------
	// Constants
	// -----------------------------------------------------------------------------------------------------------------------------

	private static let kDigestLengthBytes = 32
	private static let kChunkSize = 64
	private static let kChunkIndexMask = kChunkSize - 1
	private static let kHexDigits = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"]

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	// Initialize array of round constants:
	// (first 32 bits of the fractional parts of the cube roots of the first 64 primes 2..311)
	private static let k: [UInt32] =
	[
		0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
		0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
		0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
		0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
		0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
		0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
		0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
		0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
	]

	private var chunkIndex: Int { return bytesProcessed & Sha256.kChunkIndexMask}

	/// Internal context data for managing a continuous stream of data (via add(...))
	private var chunk: UnsafeMutablePointer<UInt8>
	private var bytesProcessed: Int = 0
	private var hash: UnsafeMutablePointer<UInt32>
	private var messageSchedule: UnsafeMutablePointer<UInt32>

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization and deinitialization
	// -----------------------------------------------------------------------------------------------------------------------------

	init()
	{
		chunk = UnsafeMutablePointer<UInt8>.allocate(capacity: Sha256.kChunkSize)
		messageSchedule = UnsafeMutablePointer<UInt32>.allocate(capacity: Sha256.kChunkSize)
		hash = UnsafeMutablePointer<UInt32>.allocate(capacity: 8)
		reset()
	}

	deinit
	{
		chunk.deallocate()
		messageSchedule.deallocate()
		hash.deallocate()
	}

	/// Initialize generation
	public func reset()
	{
		bytesProcessed = 0

		// Initialize hash values:
		// (first 32 bits of the fractional parts of the square roots of the first 8 primes 2..19)
		hash[0] = 0x6a09e667
		hash[1] = 0xbb67ae85
		hash[2] = 0x3c6ef372
		hash[3] = 0xa54ff53a
		hash[4] = 0x510e527f
		hash[5] = 0x9b05688c
		hash[6] = 0x1f83d9ab
		hash[7] = 0x5be0cd19
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Public utility methods
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Generate a hash from an Encodable
	public static func generate(from obj: Encodable) -> Hash?
	{
		if let data = obj.encode()
		{
			return Sha256.generate(fromData: data)
		}

		return nil
	}

	/// Generate a hash from a UTF8 string
	public static func generate(fromUtf8String string: String) -> Hash
	{
		let hasher = Sha256()
		hasher.add(utf8String: string)
		return hasher.finalize()
	}

	/// Generate a hash from an array
	public static func generate<T>(fromArray array: [T]) -> Hash
	{
		let hasher = Sha256()
		hasher.add(array: array)
		return hasher.finalize()
	}

	/// Generate a hash from an instance of a Data object
	public static func generate(fromData data: Data) -> Hash
	{
		let hasher = Sha256()
		hasher.add(data: data)
		return hasher.finalize()
	}

	/// Generate a hash from a raw pointer
	public static func generate(fromRawPointer ptr: UnsafeRawPointer, count: Int) -> Hash
	{
		let hasher = Sha256()
		hasher.add(rawPointer: ptr, count: count)
		return hasher.finalize()
	}

	/// Generate a hash from raw (typed) data
	public static func generate<T>(fromBytes bytes: UnsafePointer<T>, elementCount: Int) -> Hash
	{
		let hasher = Sha256()
		hasher.add(bytes: bytes, elementCount: elementCount)
		return hasher.finalize()
	}

	/// Generate a hash from UInt8 bytes
	public static func generate(fromBytes bytes: UnsafePointer<UInt8>, count: Int) -> Hash
	{
		let hasher = Sha256()
		hasher.add(bytes: bytes, count: count)
		return hasher.finalize()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Public interface (variations for adding data to the hash)
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Adds the bytes from a UTF8 string to the hash stream
	public func add(utf8String string: String)
	{
		let count = string.lengthOfBytes(using: .utf8)
		return string.withCString
		{
			add(bytes: $0, elementCount: count)
		}
	}

	/// Add the bytes from an array to the hash stream
	public func add<T>(array: [T])
	{
		array.withUnsafeBytes
		{
			if let ptr = $0.baseAddress?.assumingMemoryBound(to: UInt8.self)
			{
				add(bytes: ptr, count: array.count * MemoryLayout<T>.size)
			}
		}
	}

	/// Add the bytes from an instance of a Data object to the hash stream
	public func add(data: Data)
	{
		data.withUnsafeBytes
		{ src in
			let ptr = src.baseAddress!.assumingMemoryBound(to: UInt8.self)
			add(bytes: ptr, count: data.count)
		}
	}

	/// Add a block of raw data to the hash stream
	public func add(rawPointer ptr: UnsafeRawPointer, count: Int)
	{
		add(bytes: ptr.assumingMemoryBound(to: UInt8.self), count: count)
	}

	/// Add a block of raw (typed) data to the hash stream
	///
	/// Note that `elementCount` references the number of elements of size T in the input dataset (not the number of bytes)
	public func add<T>(bytes: UnsafePointer<T>, elementCount: Int)
	{
		let count = elementCount * MemoryLayout<T>.size
		bytes.withMemoryRebound(to: UInt8.self, capacity: count)
		{
			add(bytes: $0, count: count)
		}
	}

	/// Add a block of UInt8 bytes to the hash stream
	public func add(bytes: UnsafePointer<UInt8>, count: Int)
	{
		for i in 0..<count
		{
			addByteToChunk(bytes[i])
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Hash generation
	// -----------------------------------------------------------------------------------------------------------------------------

	// Add a single byte to the chunk, compressing at the proper intervals
	//
	/// Returns true if the byte triggered a compression and the chunk is empty, otherwise false
	@inline(__always) private func addByteToChunk(_ byte: UInt8)
	{
		chunk[chunkIndex] = byte
		bytesProcessed += 1

		if chunkIndex == 0 { compressChunk() }
	}

	/// Process a single, complete chunk
	private func compressChunk()
	{
		// Copy chunk into first 16 words w[0..15] of the message schedule array
		chunk.withMemoryRebound(to: UInt32.self, capacity: Sha256.kChunkSize / 4)
		{
			for i in 0..<16
			{
				messageSchedule[i] = $0[i].bigEndian
			}
		}

		// Extend the first 16 words into the remaining 48 words w[16..63] of the message schedule array
		for i in 16..<Sha256.kChunkSize
		{
			// s0 := (w[i-15] rightrotate 7) xor (w[i-15] rightrotate 18) xor (w[i-15] rightshift 3)
			// s1 := (w[i-2] rightrotate 17) xor (w[i-2] rightrotate 19) xor (w[i-2] rightshift 10)
			// w[i] := w[i-16] + s0 + w[i-7] + s1

			let a = messageSchedule[i - 16]
			let b = messageSchedule[i - 15]
			let c = messageSchedule[i -  7]
			let d = messageSchedule[i -  2]
			let s0 = (b >>>  7) ^ (b >>> 18) ^ (b >>  3)
			let s1 = (d >>> 17) ^ (d >>> 19) ^ (d >> 10)
			messageSchedule[i] = a &+ s0 &+ c &+ s1
		}

		// Initialize working variables to current hash value
		var a = hash[0]
		var b = hash[1]
		var c = hash[2]
		var d = hash[3]
		var e = hash[4]
		var f = hash[5]
		var g = hash[6]
		var h = hash[7]

		// Compression function main loop
		for i in 0..<Sha256.kChunkSize
		{
			// S1 := (e rightrotate 6) xor (e rightrotate 11) xor (e rightrotate 25)
			// ch := (e and f) xor ((not e) and g)
			// temp1 := h + S1 + ch + k[i] + w[i]

			let s1 = (e >>> 6) ^ (e >>> 11) ^ (e >>> 25)
			let ch = (e & f) ^ (~e & g)
			let temp1 = h &+ s1 &+ ch &+ Sha256.k[i] &+ messageSchedule[i]

			// S0 := (a rightrotate 2) xor (a rightrotate 13) xor (a rightrotate 22)
			// maj := (a and b) xor (a and c) xor (b and c)
			// temp2 := S0 + maj

			let s0 = (a >>> 2) ^ (a >>> 13) ^ (a >>> 22)
			let maj = (a & b) ^ (a & c) ^ (b & c)
			let temp2 = s0 &+ maj

			h = g
			g = f
			f = e
			e = d &+ temp1
			d = c
			c = b
			b = a
			a = temp1 &+ temp2
		}

		// Add the compressed chunk to the current hash value
		hash[0] = hash[0] &+ a
		hash[1] = hash[1] &+ b
		hash[2] = hash[2] &+ c
		hash[3] = hash[3] &+ d
		hash[4] = hash[4] &+ e
		hash[5] = hash[5] &+ f
		hash[6] = hash[6] &+ g
		hash[7] = hash[7] &+ h
	}

	/// Finalize the generation and return the hash
	public func finalize() -> Hash
	{
		// Calculate the bit length of the data in the buffer
		let bitLen = UInt64(bytesProcessed) * 8

		// append a single '1' bit
		addByteToChunk(0x80)

		// append K '0' bits, where K is the minimum number >= 0 such that L + 1 + K + 64 is a multiple of 512
		while chunkIndex != 56 { addByteToChunk(0) }

		// append L as a 64-bit big-endian integer, making the total post-processed length a multiple of 512 bits
		chunk.withMemoryRebound(to: UInt64.self, capacity: Sha256.kChunkSize / 8) { $0[7] = bitLen.bigEndian }
		compressChunk()

		// Create a hash we can return to the user in proper SHA256 big-endian format
		var hash = Hash(repeating: 0, count: Sha256.kDigestLengthBytes)
		hash.withUnsafeMutableBytes
		{
			if let ptr = $0.baseAddress?.assumingMemoryBound(to: UInt32.self)
			{
				for i in 0..<(Sha256.kDigestLengthBytes / 4)
				{
					ptr[i] = self.hash[i].bigEndian
				}
			}
		}

		return hash
	}

	/// Given a valid SHA256 digest string, this will return a `Hash` type. Otherwise, it will return nil.
	public static func hashFrom(hashString: String) -> Hash?
	{
		// Ensure the hash string has exactly the right number of characters (two characters per hash digest byte)
		if hashString.length() != Sha256.kDigestLengthBytes * 2 { return nil }

		// Make sure we're working with upper-case hash strings
		var str = hashString.uppercased()

		var result = Hash()

		// Convert the string into a `Hash` ([UInt8])
		for _ in 0..<Sha256.kDigestLengthBytes
		{
			guard let high = Sha256.kHexDigits.firstIndex(of: String(str.prefix(1))) else { return nil }
			str = String(str.suffix(str.length() - 1))

			guard let low = Sha256.kHexDigits.firstIndex(of: String(str.prefix(1))) else { return nil }
			str = String(str.suffix(str.length() - 1))

			let byte = UInt8(high<<4) | UInt8(low)
			result.append(byte)
		}

		return result
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Testing (simple sanity-check only)
	// -----------------------------------------------------------------------------------------------------------------------------

	// `current` is the hash string stored in the terminfo file
	// `secret` is the secret UUID
	// `devices` is the string of devices
	public static func sanityCheck()
	{
		let tests: [String: String] =
		[
			"":
			"E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855",
			"short":
			"F9B0078B5DF596D2EA19010C001BBD009E651DE2C57E8FB7E355F31EB9D3F739",
			"This is a test of a 32-len value":
			"AA7FF91DB9C066E69EAA3D1089D967F47EEF515899C2EB97DE324E23A1236E4D",
			"This is a test of a long string. This is a rather long string that is more than a few iterations through the data array. Please,   do enjoy this one very much. 1 2 3 4 5 6 7 8 9 0This is a test of a long string. This is a rather long string that is more than a few       iterations through the data array. Please, do enjoy this one very much. 1 2 3 4 5 6 7 8 9 0This is a test of a long string. This is a       rather long string that is more than a few iterations through the data array. Please, do enjoy this one very much. 1 2 3 4 5 6 7 8 9 0This  is a test of a long string. This is a rather long string that is more than a few iterations through the data array. Please, do enjoy this   one very much. 1 2 3 4 5 6 7 8 9 0This is a test of a long string. This is a rather long string that is more than a few iterations through  the data array. Please, do enjoy this one very much. 1 2 3 4 5 6 7 8 9 0":
			"C290DF9BCFC09A98123EBC24DAFBDDB58BD7DDB759A7EEF696579B99298B67B9"
		]

		var errors = 0
		for (data, correct) in tests
		{
			#if !os(Linux)
			let endianString = "\(CFByteOrderGetCurrent() == Int(CFByteOrderBigEndian.rawValue) ? "Big-endian" : (CFByteOrderGetCurrent() == Int(CFByteOrderLittleEndian.rawValue) ? "Little-endian":"Unknown"))"
			#else
			let endianString = "Unknown"
			#endif

			let hash = Data(Sha256.generate(fromUtf8String: data)).hexByteString(withSpaces: false)
			assert(hash == correct, "Hash sanity test failed (endianness = \(endianString)) with hash input: '\(data)'")
			if hash != correct { errors += 1 }
		}

		if errors != 0
		{
			gLogger.error("Failed Sha256 sanity check with \(errors) errors!")
		}
		else
		{
			gLogger.info("Sha256 sanity checks pass")
		}
	}
}

infix operator >>>: BitwiseShiftPrecedence

extension UInt32
{
	@inline(__always) public static func >>> (left: UInt32, right: UInt32) -> UInt32
	{
		return (left >> right) | (left << (32-right))
	}
}
