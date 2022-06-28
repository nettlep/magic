//
//  sockaddr_in.swift
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

/// Convenience extensions for conversion from `sockaddr` to `sockaddr_in`
public extension sockaddr_in
{
	/// Coversion from `sockaddr_in` to `sockaddr`
	init(_ addr: sockaddr)
	{
		var tmp = addr
		self = withUnsafePointer(to: &tmp) { $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee } }
	}

	/// Initialize a `sockaddr_in` from a `Ipv4SocketAddress`
	///
	/// Endian conversion is part of this process
	init(_ socketAddress: Ipv4SocketAddress)
	{
		#if os(Linux)
			self.init(sin_family: sa_family_t(AF_INET),
					  sin_port: in_port_t(socketAddress.port.bigEndian),
					  sin_addr: in_addr(s_addr: socketAddress.address.bigEndian),
					  sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
		#else
			self.init(sin_len: __uint8_t(MemoryLayout<sockaddr_in>.size),
					  sin_family: sa_family_t(AF_INET),
					  sin_port: in_port_t(socketAddress.port.bigEndian),
					  sin_addr: in_addr(s_addr: socketAddress.address.bigEndian),
					  sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
		#endif
	}
}
