//
//  Ipv4Address.swift
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

/// Set of common IP address (v4)
public struct Ipv4Address
{
	/// Returns an address set to INADDR_LOOPBACK
	public static let kLoopback = UInt32(INADDR_LOOPBACK)

	/// Returns an address set to INADDR_ANY
	public static let kAny = UInt32(INADDR_ANY)

	/// Returns an address set to INADDR_BROADCAST
	public static let kBroadcast = UInt32(INADDR_BROADCAST)
}
