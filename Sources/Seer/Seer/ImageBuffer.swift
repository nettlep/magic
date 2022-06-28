//
//  ImageBuffer.swift
//  Seer (Originally from Color Studio with modifications)
//
//  Created by Paul Nettle on 6/29/14.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import Dispatch
#if os(iOS)
import NativeTasksIOS
import MinionIOS
#else
import NativeTasks
import Minion
#endif

// ---------------------------------------------------------------------------------------------------------------------------------
// Convenience types
// ---------------------------------------------------------------------------------------------------------------------------------

/// Represents a 32-bit color ARGB value (used for debug output)
public typealias Color = UInt32

/// Represents an 8-bit luma value from the video input
public typealias Luma = UInt8

/// A color buffer used for debug rendering
public typealias DebugBuffer = ImageBuffer<Color>

/// A luminance buffer used as input to the scanning process
public typealias LumaBuffer = ImageBuffer<Luma>

// ---------------------------------------------------------------------------------------------------------------------------------
// Global functions
// ---------------------------------------------------------------------------------------------------------------------------------

/// Performs an alpha blend with the following equation:
///
/// color = src_color * src_alpha + dst_color * (1 - src_alpha)
/// alpha = dst_alpha
@inline(__always) public func alphaBlend(src: Color, dst: Color) -> Color
{
	let a = src >> 24
	let srcRB = src & 0x00ff00ff
	let dstRB = dst & 0x00ff00ff
	let rb = ((srcRB * a) + (dstRB * (0xff - a))) & 0xff00ff00
	let srcG = src & 0x0000ff00
	let dstG = dst & 0x0000ff00
	let g = ((srcG * a) + (dstG * (0xff - a))) & 0x00ff0000
	return (dst & 0xff000000) | ((rb | g) >> 8)
}

/// Defines an image buffer, capable of storing image data and operating on it in various ways
public final class ImageBuffer<Sample>
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The width of the image
	public let width: Int

	/// The height of the image
	public let height: Int

	/// The buffer of image samples
	public let buffer: UnsafeMutablePointer<Sample>

	/// Internal flag that denotes if `buffer` was allocated by this class
	///
	/// If `bufferOwner` is true, then this memory will be cleaned up in de-initialization
	public let bufferOwner: Bool

	/// Returns a local-space (zero-based) rectangle with a width & height matching the dimensions of this `ImageBuffer`
	public var rect: Rect<Int> { return Rect(x: 0, y: 0, width: width, height: height) }

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize an empty ImageBuffer
	///
	/// This is generally useful as a placeholder until a real object can be allocated
	/// allocated upon initialization and released back to the system upon de-initialization.
	///
	/// To use `ImageBuffer` as a way to wrap an existing buffer of image samples, see `init(width:height:buffer:)`
	public init()
	{
		self.width = 0
		self.height = 0
		self.buffer = UnsafeMutablePointer<Sample>.allocate(capacity: 0)
		self.bufferOwner = true
	}

	/// Perform base initialization of an `ImageBuffer`
	///
	/// Use this form of `ImageBuffer` to create an `ImageBuffer` of a given size. The memory for the image samples will be
	/// allocated upon initialization and released back to the system upon de-initialization.
	///
	/// To use `ImageBuffer` as a way to wrap an existing buffer of image samples, see `init(width:height:buffer:)`
	public init(width: Int, height: Int)
	{
		self.width = width
		self.height = height
		self.buffer = UnsafeMutablePointer<Sample>.allocate(capacity: self.width * self.height)
		self.bufferOwner = true
	}

	/// Perform base initialization of a transient `ImageBuffer`
	///
	/// Use this form of `ImageBuffer` to wrap an existing buffer of samples. The buffer must be packed; that is, the stride must
	/// be equal to the width of the buffer multiplied by the size of each `Sample` in bytes.
	///
	/// To create an `ImageBuffer` that manages its own memory buffer, see `init(width:height:)`
	public init(width: Int, height: Int, buffer: UnsafeMutablePointer<Sample>)
	{
		self.width = width
		self.height = height
		self.buffer = buffer
		self.bufferOwner = false
	}

	/// Cleans up any resources owned by this `ImageBuffer`
	///
	/// Note that if the `ImageBuffer` being de-initialized is the transient form (see `init(width:height:buffer:)`), then the
	/// `buffer` memory is not deallocated.
	deinit
	{
		if bufferOwner
		{
			buffer.deallocate()
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Sampling
	// -----------------------------------------------------------------------------------------------------------------------------

	public func sample(from point: Vector) -> Sample?
	{
		return sample(from: point.chopToPoint())
	}

	public func sample(from point: IVector) -> Sample?
	{
		if !rect.contains(point: point) { return nil }

		return buffer[point.y * width + point.x]
	}

	/// Calculates a histogram from the input data and draws it to the image
	/// 
	/// The input data is interpreted differently depending on the state of the `rawData` flag.
	///
	///     * If this flag is true (the default) then the data is considered raw and a 256-sample histogram of that data is
	///       calculated. Each value in the resulting histogram represents the frequency at which that value appears in the data.
	///	      This requires that the input data all be in the range of [0, 255].
	///
	///     * If the flag is false, then the data is treated as a histogram chart and it will be displayed in the best way
	///       appropriate.
	///
	/// The histogram's size on screen is carefully calculated such that every bar in the histogram will be of the exact same
	/// integer width. As a result, not all histograms will display the same, depending on how their samples fit into integer
	/// buckets.
	public func drawHistogram(data: [Int], rawData: Bool = true, offset: Int = 0)
	{
		// No data? No histogram
		if data.isEmpty { return }

		// Generate our histogram
		var histogram: [Int]
		if rawData
		{
			histogram = [Int](repeating: 0, count: 256)
			for val in data
			{
				histogram[val] += 1
			}
		}
		else
		{
			histogram = data
		}

		// Calculate our max
		var maxValue = 0
		for val in histogram
		{
			maxValue = max(val, maxValue)
		}

		// Our histogram size, within the image
		let chartWidth = ((width - 1) / histogram.count) * histogram.count
		let chartHeight = height / 5
		let chartLeft = (width - chartWidth) / 2
		let chartBottom = height - 1 - height / 5 - offset

		// The width of a single element
		let elementWidth = chartWidth / histogram.count

		// Our bar width is constant across the entire chart
		let barWidth = elementWidth / 2
		let gapWidth = elementWidth / 2

		// Starting at the left side (offset by the first gap)
		var xPos = chartLeft + gapWidth / 2

		let histogramRect = Rect<Int>(minX: chartLeft,
		                              minY: chartBottom - chartHeight,
		                              maxX: chartLeft + chartWidth,
		                              maxY: chartBottom)
		histogramRect.fill(to: self as Any as? DebugBuffer, color: 0xc0606060)

		for val in histogram
		{
			// Scale val to the size of our chart
			let barHeight = maxValue == 0 ? 0 : Int(Real(val) / Real(maxValue) * Real(chartHeight))

			// Draw the bar
			let r2 = Rect<Int>(minX: xPos, minY: chartBottom - barHeight, maxX: xPos + barWidth, maxY: chartBottom)
			r2.fill(to: self as Any as? DebugBuffer, color: 0xffffffff)

			// Next!
			xPos += barWidth + gapWidth
		}
	}
}
