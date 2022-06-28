//
//  UnsafeRawPointer.swift
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

public extension UnsafeRawPointer
{
	func toData(count: Int, elementSize: Int) -> Data?
	{
		return Data(bytes: self, count: count * elementSize)
	}
}

#if os(macOS)
public extension UnsafeRawPointer
{
	func toCGImage(width: Int, height: Int, elementSize: Int) -> CGImage?
	{
		return toData(count: width * height, elementSize: elementSize)?.toCGImage(width: width, height: height, bytesPerPixel: elementSize)
	}

	func toNSImage(width: Int, height: Int, elementSize: Int) -> NSImage?
	{
		return toData(count: width * height, elementSize: elementSize)?.toNSImage(width: width, height: height, bytesPerPixel: elementSize)
	}
}
#endif
