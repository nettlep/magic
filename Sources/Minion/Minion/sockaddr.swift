//
//  sockaddr.swift
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

/// Convenience extensions for conversion from `sockaddr_in` to `sockaddr`
public extension sockaddr
{
	/// Coversion from `sockaddr_in` to `sockaddr`
	init(_ addr: sockaddr_in)
	{
		var tmp = addr
		self = withUnsafePointer(to: &tmp) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0.pointee } }
	}
}
