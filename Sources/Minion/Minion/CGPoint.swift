//
//  CGPoint.swift
//  Minion
//
//  Created by Paul Nettle on 10/4/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

#if os(iOS)
import UIKit

extension CGPoint
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Arithmetic
	// -----------------------------------------------------------------------------------------------------------------------------

	@inline(__always) public static func + (left: CGPoint, right: CGPoint) -> CGPoint
	{
		var result = CGPoint(x: left.x, y: left.y)
		result += right
		return result
	}

	@inline(__always) public static func + (left: CGPoint, right: CGFloat) -> CGPoint
	{
		var result = CGPoint(x: left.x, y: left.y)
		result += right
		return result
	}

	@inline(__always) public static func += (left: inout CGPoint, right: CGPoint)
	{
		left.x += right.x
		left.y += right.y
	}

	@inline(__always) public static func += (left: inout CGPoint, right: CGFloat)
	{
		left.x += right
		left.y += right
	}

	@inline(__always) public static func - (left: CGPoint, right: CGPoint) -> CGPoint
	{
		var result = CGPoint(x: left.x, y: left.y)
		result -= right
		return result
	}

	@inline(__always) public static func - (left: CGPoint, right: CGFloat) -> CGPoint
	{
		var result = CGPoint(x: left.x, y: left.y)
		result -= right
		return result
	}

	@inline(__always) public static func -= (left: inout CGPoint, right: CGPoint)
	{
		left.x -= right.x
		left.y -= right.y
	}

	@inline(__always) public static func -= (left: inout CGPoint, right: CGFloat)
	{
		left.x -= right
		left.y -= right
	}

	@inline(__always) public static func * (left: CGPoint, right: CGPoint) -> CGPoint
	{
		var result = CGPoint(x: left.x, y: left.y)
		result *= right
		return result
	}

	@inline(__always) public static func * (left: CGPoint, right: CGFloat) -> CGPoint
	{
		var result = CGPoint(x: left.x, y: left.y)
		result *= right
		return result
	}

	@inline(__always) public static func *= (left: inout CGPoint, right: CGPoint)
	{
		left.x *= right.x
		left.y *= right.y
	}

	@inline(__always) public static func *= (left: inout CGPoint, right: CGFloat)
	{
		left.x *= right
		left.y *= right
	}

	@inline(__always) public static func / (left: CGPoint, right: CGPoint) -> CGPoint
	{
		var result = CGPoint(x: left.x, y: left.y)
		result /= right
		return result
	}

	@inline(__always) public static func / (left: CGPoint, right: CGFloat) -> CGPoint
	{
		var result = CGPoint(x: left.x, y: left.y)
		result /= right
		return result
	}

	@inline(__always) public static func /= (left: inout CGPoint, right: CGPoint)
	{
		left.x /= right.x
		left.y /= right.y
	}

	@inline(__always) public static func /= (left: inout CGPoint, right: CGFloat)
	{
		left.x /= right
		left.y /= right
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Negation
	// -----------------------------------------------------------------------------------------------------------------------------

	@inline(__always) public static prefix func - (v: CGPoint) -> CGPoint
	{
		return CGPoint(x: -v.x, y: -v.y)
	}
}
#endif
