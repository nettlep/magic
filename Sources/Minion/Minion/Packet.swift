//
//  Packet.swift
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

/// Representation of a packet of transferrable data
///
/// Packets are versioned, encrypted and signed wrappers around data to be transferred.
///
/// The format of a packet on the wire is:
///
///     <packet-version><encryption codec><encrypted data>
public final class Packet
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The maximum allowed size of a packet - this is the IP packet size with an allowance of a total of 4K headers
	///
	/// Note that this value represents the entire packet size (including any size values that are part of the packet itself)
	public static let kMaxPacketSizeBytes = 65536 - 4096

	/// The version of packets produced by this version of the code
	private static let kVersion: UInt16 = 1

	// -----------------------------------------------------------------------------------------------------------------------------
	// Public types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The payload is the data intended to be transmitted
	public struct Payload: Codable
	{
		/// Information pertaining to a payload
		public struct Info: Codable
		{
			/// Version of the payload data
			///
			/// This value is intended to be used as a form of protocol versioning, allowing the calling code to support versioned
			/// data. If this is not used, it should be set to 0 to allow for future versioning.
			public let version: UInt16

			/// Payload identification
			///
			/// A uuid (use a tool like `uuidgen` to generate)
			public let id: String

			/// Encodable conformance
			public func encode(into data: inout Data) -> Bool
			{
				if !version.encode(into: &data) { return false }
				if !id.encode(into: &data) { return false }
				return true
			}

			/// Decodable conformance
			public static func decode(from data: Data, consumed: inout Int) -> Info?
			{
				guard let version = UInt16.decode(from: data, consumed: &consumed) else { return nil }
				guard let id = String.decode(from: data, consumed: &consumed) else { return nil }
				return Info(version: version, id: id)
			}
		}

		/// Information pertaining to this payload
		public let info: Info

		/// The payload data
		public let data: Data

		/// Initialize the payload with base values
		init(info: Info, data: Data)
		{
			self.info = info
			self.data = data
		}

		/// Initialize the payload with a version, ID and data
		init(version: UInt16, id: String, data: Data)
		{
			self.info = Info(version: version, id: id)
			self.data = data
		}

		/// Send this `Payload` to the receiver defined by `to`
		public func send(to socketAddress: Ipv4SocketAddress, over socket: Socket) -> Bool
		{
			return Packet.construct(fromPayload: self)?.send(to: socketAddress, over: socket) ?? false
		}

		/// Encodable conformance
		public func encode(into data: inout Data) -> Bool
		{
			if !self.info.encode(into: &data) { return false }
			if !self.data.encode(into: &data) { return false }
			return true
		}

		/// Decodable conformance
		public static func decode(from data: Data, consumed: inout Int) -> Payload?
		{
			guard let info = Info.decode(from: data, consumed: &consumed) else { return nil }
			guard let data = Data.decode(from: data, consumed: &consumed) else { return nil }
			return Payload(info: info, data: data)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Internal types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Digest used for signing packets
	///
	/// This is a culmination of multiple values from within the packet, such that the signature is dependent upon the packet's
	/// actual contents (i.e., it does not sign the packet data itself.)
	private struct Digest: Codable
	{
		/// Our shared secret, must be present on client and server
		private static let kSecret = "7m-XVcs`dT77uYP;w2fVBG.n??A&r:^C"

		let packetVersion: UInt16
		let codec: CodecProvider
		let payloadInfo: Payload.Info
		let payloadSizeBytes: UInt16
		let secret: String

		/// Initialize our digest with the base values
		init(packetVersion: UInt16, codec: CodecProvider, payloadInfo: Payload.Info, payloadSizeBytes: UInt16, secret: String)
		{
			self.packetVersion = packetVersion
			self.codec = codec
			self.payloadInfo = payloadInfo
			self.payloadSizeBytes = payloadSizeBytes
			self.secret = secret
		}

		/// Initialize our digest with the pertinent data
		init(packetVersion: UInt16, codec: CodecProvider, payload: Payload)
		{
			self.packetVersion = packetVersion
			self.codec = codec
			self.payloadInfo = payload.info
			self.payloadSizeBytes = UInt16(payload.data.count)
			self.secret = Digest.kSecret
		}

		/// Generate the hash from the contents of this digest
		public func generateHash() -> Sha256.Hash?
		{
			if let data = encode()
			{
				return Sha256.generate(fromData: data)
			}

			return nil
		}

		/// Encodable conformance
		public func encode(into data: inout Data) -> Bool
		{
			if !packetVersion.encode(into: &data) { return false }
			if !codec.encode(into: &data) { return false }
			if !payloadInfo.encode(into: &data) { return false }
			if !payloadSizeBytes.encode(into: &data) { return false }
			if !secret.encode(into: &data) { return false }
			return true
		}

		/// Decodable conformance
		public static func decode(from data: Data, consumed: inout Int) -> Digest?
		{
			guard let packetVersion = UInt16.decode(from: data, consumed: &consumed) else { return nil }
			guard let encryptionAlgorithm = EncryptionAlgorithm.decode(from: data, consumed: &consumed) else { return nil }
			guard let payloadInfo = Payload.Info.decode(from: data, consumed: &consumed) else { return nil }
			guard let payloadSizeBytes = UInt16.decode(from: data, consumed: &consumed) else { return nil }
			guard let secret = String.decode(from: data, consumed: &consumed) else { return nil }
			let codec = CodecFactory.createCodec(algorithm: encryptionAlgorithm)
			return Digest(packetVersion: packetVersion, codec: codec, payloadInfo: payloadInfo, payloadSizeBytes: payloadSizeBytes, secret: secret)
		}
	}

	/// Data to be encrypted within a packet
	///
	/// Much of the packet is encrypted by one of the codecs (such as `EntropyCodec`.) This block of data represents that encrypted
	/// data.
	private struct EncryptionPackage: Codable
	{
		/// The payload being transmitted within this packet
		let payload: Payload

		/// SHA256 hash representing the packet's signature
		let hashData: Sha256.Hash

		/// Initialize the `EncryptPackage` from input data
		init?(payload: Payload, digest: Digest)
		{
			self.payload = payload

			guard let hashData = digest.generateHash() else
			{
				gLogger.error("Failed to generate digest hash")
				return nil
			}

			self.hashData = hashData
		}

		/// Initialize the `EncryptPackage`
		private init(payload: Payload, hashData: Sha256.Hash)
		{
			self.payload = payload
			self.hashData = hashData
		}

		/// Returns the encrypted data for this package
		func encrypt(withCodec codec: CodecProvider) -> Data?
		{
			guard let data = self.encode() else { return nil }
			return codec.encrypt(data)
		}

		/// Returns the encrypted data for this package
		static func decrypt(withCodec codec: CodecProvider, fromData data: Data) -> EncryptionPackage?
		{
			var consumed = 0
			let decryptedData = codec.decrypt(data)
			guard let package = EncryptionPackage.decode(from: decryptedData, consumed: &consumed) else { return nil }

			assert(consumed == decryptedData.count)
			if consumed != decryptedData.count
			{
				gLogger.error("Corrupt packet - consumed \(consumed) out of \(decryptedData.count)")
				return nil
			}

			return package
		}

		/// Encodable conformance
		public func encode(into data: inout Data) -> Bool
		{
			if !payload.encode(into: &data) { return false }
			if !hashData.encode(into: &data) { return false }
			return true
		}

		/// Decodable conformance
		public static func decode(from data: Data, consumed: inout Int) -> EncryptionPackage?
		{
			guard let payload = Payload.decode(from: data, consumed: &consumed) else { return nil }
			guard let hashData = Sha256.Hash.decode(from: data, consumed: &consumed) else { return nil }
			return EncryptionPackage(payload: payload, hashData: hashData)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Internal properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The version of packet being transmitted
	///
	/// Currently, we only support version 1
	fileprivate let version: UInt16

	/// The codec used to encrypt this packet
	fileprivate let codec: CodecProvider

	/// The encrypted data of this packet
	fileprivate let encryptedData: Data

	// -----------------------------------------------------------------------------------------------------------------------------
	// Internal initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Init from base values
	fileprivate init(version: UInt16, codec: CodecProvider, encryptedData: Data)
	{
		self.version = version
		self.codec = codec
		self.encryptedData = encryptedData
	}

	/// Internal initialization for a packet. This method is not intended to be used by calling code. Instead, use `construct()`
	/// and `deconstruct()` methods to work with Packets.
	fileprivate init?(version: UInt16, codec: CodecProvider, payload: Payload)
	{
		self.version = version
		self.codec = codec

		let digest = Digest(packetVersion: version, codec: codec, payload: payload)
		guard let encryptionPackage = EncryptionPackage(payload: payload, digest: digest) else { return nil }

		guard let encryptedData = encryptionPackage.encrypt(withCodec: self.codec) else { return nil }
		self.encryptedData = encryptedData
	}

	/// Send this `Paacket` to the receiver defined by `to`
	public func send(to socketAddress: Ipv4SocketAddress, over socket: Socket) -> Bool
	{
		guard let data = encode() else
		{
			gLogger.error("Packet.send: Failed to encode packet")
			return false
		}

		// Final packet size validation
		assert(data.count <= Packet.kMaxPacketSizeBytes)
		if data.count > Packet.kMaxPacketSizeBytes
		{
			gLogger.error("Packet.send: size (\(data.count)) exceeds maximum (\(Packet.kMaxPacketSizeBytes))")
			return false
		}

		if socket.send(data, to: socketAddress) != data.count
		{
			gLogger.error("Packet.send: Not all data was sent")
			return false
		}

		return true
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Public class methods
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Generates a `Data` object representing a signed, encrypted packet wrapped around the given `payload`.
	///
	/// Use `deconstruct()` to reverse this packet back into a `Payload`
	///
	/// A packet can fail construction for a few reasons: `payload` is too large for a single packet (see
	/// `Packet.kMaxPacketSizeBytes`) or there is an internal coding issue.
	public class func construct(fromPayload payload: Payload) -> Packet?
	{
		// This is only a sanity check - note that a packet's overhead will reduce the actual available space allowed for
		// payload data
		assert(payload.data.count <= Packet.kMaxPacketSizeBytes)
		if payload.data.count > Packet.kMaxPacketSizeBytes
		{
			gLogger.error("Payload size (\(payload.data.count)) exceeds max packet size (\(Packet.kMaxPacketSizeBytes))")
			return nil
		}

		let codec = CodecFactory.createCodec(algorithm: .Entropy)

		guard let packet = Packet(version: Packet.kVersion, codec: codec, payload: payload) else
		{
			gLogger.error("Failed to build packet")
			return nil
		}

		return packet
	}

	/// Deconstructs a `Data` object representing a signed, encrypted packet into a `Payload`.
	///
	/// Packets are created using the `construct()` method.
	///
	/// Returns the `Payload` on success, otherwise nil.
	public class func deconstruct(fromData data: Data) -> Payload?
	{
		guard let packet = Packet.decode(from: data) else
		{
			gLogger.error("Failed to decode packet")
			return nil
		}

		guard let encryptionPackage = EncryptionPackage.decrypt(withCodec: packet.codec, fromData: packet.encryptedData) else
		{
			gLogger.error("Failed to decrypt package")
			return nil
		}

		let digest = Digest(packetVersion: packet.version, codec: packet.codec, payload: encryptionPackage.payload)
		guard let thisHash = digest.generateHash() else
		{
			gLogger.error("Failed to generate digest for package validation")
			return nil
		}
		if thisHash != encryptionPackage.hashData
		{
			gLogger.error("Validation failure")
			return nil
		}

		return encryptionPackage.payload
	}
}

extension Packet: Codable
{
	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !version.encode(into: &data) { return false }
		if !codec.encode(into: &data) { return false }
		if !encryptedData.encode(into: &data) { return false }
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> Packet?
	{
		guard let version = UInt16.decode(from: data, consumed: &consumed) else { return nil }
		guard let codec = CodecFactory.createCodec(from: data, consumed: &consumed) else { return nil }
		guard let encryptedData = Data.decode(from: data, consumed: &consumed) else { return nil }
		return Packet(version: version, codec: codec, encryptedData: encryptedData)
	}
}
