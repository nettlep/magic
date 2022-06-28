//
//  CodecFactory.swift
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

/// Supported encryption algorithms
public enum EncryptionAlgorithm: UInt8
{
	case Entropy = 1
}

/// Codable conformance
extension EncryptionAlgorithm: Codable
{
	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		return rawValue.encode(into: &data)
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> EncryptionAlgorithm?
	{
		guard let rawValue = UInt8.decode(from: data, consumed: &consumed) else { return nil }
		return EncryptionAlgorithm(rawValue: rawValue)
	}
}

/// Protocol for an encryption implementations
internal protocol CodecProvider: Codable
{
 	/// Returns the name of this codec
	static var name: String { get }

	/// Returns the `EncryptionAlgorithm`
	static var algorithm: EncryptionAlgorithm { get }

	/// Encrypt `data` using the given algorithm
	func encrypt(_ data: Data) -> Data

	/// Decrypt `data` using the given algorithm
	func decrypt(_ data: Data) -> Data

	/// Standard initializer for creating a codec
	init()
}

/// Factory for creating/decoding `CodecProviders`
internal class CodecFactory
{
	/// Returns the codec from the given encryption algorithm
	public static func createCodec(algorithm: EncryptionAlgorithm) -> CodecProvider
	{
		// Generate codec data
		switch algorithm
		{
			case .Entropy: return EntropyCodec()
		}
	}

	/// Returns a codec via decoding
	public static func createCodec(from data: Data, consumed: inout Int) -> CodecProvider?
	{
		// We just want to peek at the algorithm, so we'll pass in a temporary value for `consumed`
		var tmpConsumed = consumed
		guard let rawAlgorithm = UInt8.decode(from: data, consumed: &tmpConsumed) else { return nil }

		// Get an actual `EncryptionAlgorithm` from our raw value
		guard let algorithm = EncryptionAlgorithm(rawValue: rawAlgorithm) else { return nil }

		// Decode a `CodecProvider` of the correct type
		switch algorithm
		{
			case .Entropy: return EntropyCodec.decode(from: data, consumed: &consumed)
		}
	}
}
