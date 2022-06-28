//
//  UnsafePointer.swift
//  Minion
//
//  Created by Paul Nettle on 3/31/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

public extension UnsafePointer
{
	func toData(count: Int) -> Data?
	{
		let elementSize = MemoryLayout<Pointee>.size
		return Data(bytes: self, count: count * elementSize)
	}
}

#if os(macOS) || os(iOS)
public extension UnsafePointer
{
	func toCGImage(width: Int, height: Int) -> CGImage?
	{
		let elementSize = MemoryLayout<Pointee>.size
		return toData(count: width * height)?.toCGImage(width: width, height: height, bytesPerPixel: elementSize)
	}

#if os(macOS)
	func toNSImage(width: Int, height: Int) -> NSImage?
	{
		let elementSize = MemoryLayout<Pointee>.size
		return toData(count: width * height)?.toNSImage(width: width, height: height, bytesPerPixel: elementSize)
	}
#endif
}
#endif
