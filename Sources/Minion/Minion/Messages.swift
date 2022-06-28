//
//  Messages.swift
//  Minion
//
//  Created by Paul Nettle on 2/20/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

// ---------------------------------------------------------------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------------------------------------------------------------

/// Protocol for network payloads
public protocol NetMessage: Codable
{
	var payloadVersion: UInt16 { get }
	static var payloadId: String { get }
	func getPayload() -> Packet.Payload?
}

/// Default implementations for NetMessage
extension NetMessage
{
	/// The default payload version for all messages
	public var payloadVersion: UInt16 { return 0 }

	/// Default implementation to construct a `Packet.Payload` from a `NetMessage`
	///
	/// This simply encodes the `NetMessage` and creates a `Packet.Payload` from that encoded data
	public func getPayload() -> Packet.Payload?
	{
		guard let data = encode() else { return nil }
		return Packet.Payload(version: payloadVersion, id: type(of: self).payloadId, data: data)
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Handshake messages
// ---------------------------------------------------------------------------------------------------------------------------------

/// An advertisement message
///
/// Sent from clients to silently awaiting servers via UDP broadcast
public struct AdvertiseMessage: NetMessage
{
	/// The Payload Id for this message
	public static var payloadId: String { return "DA737AE6-2CCD-4C00-9936-A0FF08041ECE" }

	/// The client's control port
	let controlPort: UInt16

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !controlPort.encode(into: &data) { return false }
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> AdvertiseMessage?
	{
		guard let controlPort = UInt16.decode(from: data, consumed: &consumed) else { return nil }
		return AdvertiseMessage(controlPort: controlPort)
	}
}

/// An advertisement acknowledgement message
///
/// Sent from servers to clients on the client's control port
public struct AdvertiseAckMessage: NetMessage
{
	/// The Payload Id for this message
	public static var payloadId: String { return "0630FA19-9FE6-4E64-AE3A-C957A1210DC4" }

	/// The server's control port
	public let controlPort: UInt16

	public init(controlPort: UInt16)
	{
		self.controlPort = controlPort
	}

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !controlPort.encode(into: &data) { return false }
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> AdvertiseAckMessage?
	{
		guard let controlPort = UInt16.decode(from: data, consumed: &consumed) else { return nil }
		return AdvertiseAckMessage(controlPort: controlPort)
	}
}

/// A ping message
///
/// Sent from servers to clients on the client's control port
public struct PingMessage: NetMessage
{
	/// The Payload Id for this message
	public static var payloadId: String { return "E7E77CAA-CD1D-4BFC-B569-3C0062587EED" }

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		// Our payload is empty
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> PingMessage?
	{
		// Our payload is empty, just instantiate a PingMessage
		return PingMessage()
	}
}

/// A ping acknowledgement message
///
/// Sent from clients to servers on the server's control port
public struct PingAckMessage: NetMessage
{
	/// The Payload Id for this message
	public static var payloadId: String { return "902978C6-D26E-4995-90AC-0F76B90F1F71" }

	/// Force a public initializer
	public init()
	{
	}

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		// Our payload is empty
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> PingAckMessage?
	{
		// Our payload is empty, just instantiate a PingAckMessage
		return PingAckMessage()
	}
}

/// A disconnection message
///
/// Sent from either clients or servers to the peer's control port
public struct DisconnectMessage: NetMessage
{
	/// The Payload Id for this message
	public static var payloadId: String { return "A0AC6BA2-D585-47EF-BBDF-51846EB9A512" }

	/// The string reason for the disconnection
	public let reason: String

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !reason.encode(into: &data) { return false }
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> DisconnectMessage?
	{
		guard let reason = String.decode(from: data, consumed: &consumed) else { return nil }
		return DisconnectMessage(reason: reason)
	}
}
