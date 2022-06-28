//
//  Ipv4Interface.swift
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

/// Representation of an IPv4 interface device (address family must be AF_INET only)
public struct Ipv4Interface
{
	/// The interface name ('en0', 'eth0', 'wlan0', etc.)
	private(set) public var name: String?

	/// The IP address associated to this interface
	private(set) public var address: UInt32

	/// The netmask associated to this interface
	private(set) public var netmask: UInt32

	/// The gateway associated to this interface
	private(set) public var gateway: UInt32

	/// Returns true if the interface supports broadcast
	///
	/// The rules are:
	///     1. We must have an interface index
	///     2. The IP address must be valid and not loopback or empty
	///     3. We must have a netmask and a gateway
	public var supportsBroadcast: Bool
	{
		return address != Ipv4Address.kAny && address != Ipv4Address.kLoopback && netmask != Ipv4Address.kAny && gateway != Ipv4Address.kAny && index != nil
	}

	/// Returns the index of this interface
	///
	/// Because the index is found by the interface name, it's possible that there may be no index, in which case, this interface
	/// is wholly invalid.
	public var index: UInt32?
	{
		if name == nil { return nil }
		let index = if_nametoindex(name!)
		if index == 0 { return nil }
		return index
	}

	/// Initialize an Ipv4Interface from its base elements
	init(name: String?, address: UInt32, netmask: UInt32, gateway: UInt32)
	{
		self.name = name
		self.address = address
		self.netmask = netmask
		self.gateway = gateway
	}

	/// Initialize an Ipv4Interface from an `ifaddrs`
	///
	/// This is typically useful when enumerating interfaces from the socket layer.
	public init?(_ interface: ifaddrs)
	{
		// We only support the AF_INET address family
		if interface.ifa_addr.pointee.sa_family != UInt16(AF_INET) { return nil }

		name = interface.ifa_name == nil ? nil : String(cString: interface.ifa_name)
		address = UInt32(bigEndian: sockaddr_in(interface.ifa_addr.pointee).sin_addr.s_addr)
		netmask = UInt32(bigEndian: sockaddr_in(interface.ifa_netmask.pointee).sin_addr.s_addr)
		#if os(Linux)
			gateway = UInt32(bigEndian: sockaddr_in(interface.ifa_ifu.ifu_dstaddr.pointee).sin_addr.s_addr)
		#else
			gateway = UInt32(bigEndian: sockaddr_in(interface.ifa_dstaddr.pointee).sin_addr.s_addr)
		#endif
	}

	/// Returns a list of interfaces that with an optional filter on support for broadcast traffic
	public static func enumerateInterfaces(requireBroadcast: Bool) -> [Ipv4Interface]
	{
		var interfaces = [Ipv4Interface]()
		var ifaddrs: UnsafeMutablePointer<ifaddrs>?
		if getifaddrs(&ifaddrs) != 0
		{
			gLogger.error("Unable to get interface addresses")
			return interfaces
		}

		while ifaddrs != nil
		{
			if let interface = Ipv4Interface(ifaddrs!.pointee)
			{
				if (!requireBroadcast) || interface.supportsBroadcast
				{
					interfaces.append(interface)
				}
			}

			ifaddrs = ifaddrs?.pointee.ifa_next
		}

		return interfaces
	}
}

extension Ipv4Interface: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		let nameString = "\(name ?? "[none]")"
		let indexString = "index=\(index == nil ? "[none]" : "\(index!)")"
		let addressString = "address=\(address.toIPAddress())"
		let netmaskString = "netmask=\(netmask.toIPAddress())"
		let gatewayString = "gateway=\(gateway.toIPAddress())"

		return "\(nameString): \(indexString), \(addressString), \(netmaskString), \(gatewayString)"
	}
}
