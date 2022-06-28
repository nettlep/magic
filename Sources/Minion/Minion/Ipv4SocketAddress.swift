//
//  Ipv4SocketAddress.swift
//  Minion
//
//  Created by Paul Nettle on 1/28/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// A representation of a socket address (`sockaddr_in`), which, for AF_INET sockets is generally an IP/Port address pair
///
/// The internal representation for the address and port is in host byte order.
public struct Ipv4SocketAddress
{
	/// The IP address
	public let address: UInt32

	/// The port address
	public let port: UInt16

	/// Initialize from the base types, both of which are in host byte format
	public init(address: UInt32, port: UInt16)
	{
		self.address = address
		self.port = port
	}

	/// Initialize from a `sockaddr_in`
	public init(_ addr: sockaddr_in)
	{
		address = in_addr_t(bigEndian: addr.sin_addr.s_addr)
		port = in_port_t(bigEndian: addr.sin_port)
	}

	/// Returns a string representation of this socket address
	public func toString() -> String
	{
		return "\(address.toIPAddress()):\(port)"
	}
}

extension Ipv4SocketAddress: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		return toString()
	}
}

extension Ipv4SocketAddress: Equatable
{
	public static func == (lhs: Ipv4SocketAddress, rhs: Ipv4SocketAddress) -> Bool
	{
		return lhs.address == rhs.address
	}
}
