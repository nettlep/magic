//
//  ImageBuffer-Copy.swift
//  Seer
//
//  Created by Paul Nettle on 2/27/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
#if os(iOS)
import NativeTasksIOS
import MinionIOS
#else
import NativeTasks
import Minion
#endif

/// Specialization of ImageBuffer for Luma samples
extension ImageBuffer where Sample == Luma
{
	/// Initialize a new `ImageBuffer` from `source`
	///
	/// See `copy(from:width:height:)` for details on how the copy is performed
	public convenience init(_ source: ImageBuffer<Luma>)
	{
		self.init(width: source.width, height: source.height)
		copy(from: source.buffer, width: source.width, height: source.height)
	}

	/// Initialize a new `ImageBuffer` from `source`
	///
	/// See `copy(from:width:height:)` for details on how the copy is performed
	///
	/// Throws:
	///		* ImageError.DimensionMismatch if `width` and `height` do not match this image
	public convenience init(_ source: ImageBuffer<Color>) throws
	{
		self.init(width: source.width, height: source.height)
		try copy(from: source.buffer, width: source.width, height: source.height)
	}

	/// Copies image data from `source` into this `ImageBuffer`
	///
	/// See `copy(from:width:height:)` for details on how the copy is performed
	///
	/// Note that if `width` and `height` do not match, a nearest-neighbor resample copy is performed
	public func copy(from source: ImageBuffer<Luma>)
	{
		copy(from: source.buffer, width: source.width, height: source.height)
	}

	/// Copies image data from `source` into this `ImageBuffer`
	///
	/// See `copy(from:width:height:)` for details on how the copy is performed
	///
	/// Throws:
	///		* ImageError.DimensionMismatch if `width` and `height` do not match this image
	public func copy(from source: ImageBuffer<Color>) throws
	{
		try copy(from: source.buffer, width: source.width, height: source.height)
	}

	/// Initialize a new `ImageBuffer` from `source` buffer in the 2vuy format (i.e., interleaved 16-bit YUV)
	///
	/// Note that the input buffer is assumed to be the same dimensions as this image. Specifically, it must contain at lease `width * height * 2` bytes.
	public func copy(from2vuyBuffer buffer: UnsafeMutablePointer<Luma>)
	{
		nativeCopy2vuyToLuma(buffer, self.buffer, UInt32(width), UInt32(height))
	}

	/// Copies `source` into `buffer`
	///
	/// As the types are matching, no conversion is performed and the image data is simply copied directly from `source`
	///
	/// Note that if `width` and `height` do not match, a nearest-neighbor resample copy is performed
	public func copy(from source: UnsafeMutablePointer<Luma>, width: Int, height: Int)
	{
		if self.width == width && self.height == height
		{
			buffer.initialize(from: source, count: width * height)
		}
		else
		{
			resampleNearestNeighbor(from: source, width: width, height: height)
		}
	}

	/// Copies `source` into `buffer`
	///
	/// The `source` image data is reduced to monochrome image data during the copy
	///
	/// Note that `width` and `height` must match those within this `ImageBuffer`
	///
	/// Throws:
	///		* ImageError.DimensionMismatch if `width` and `height` do not match this image
	public func copy(from source: UnsafeMutablePointer<Color>, width: Int, height: Int) throws
	{
		assert(self.width == width && self.height == height)
		if self.width != width || self.height != height
		{
			throw ImageError.DimensionMismatch
		}

		nativeCopyColorToLuma(source, buffer, UInt32(width), UInt32(height))

		//let count = width * height
		//for i in 0..<count
		//{
		//	let pix = source[i]
		//	let r = (pix >> 16) & 0xff
		//	let g = (pix >>  8) & 0xff
		//	let b = (pix >>  0) & 0xff
		//	buffer[i] = Luma(max(r, max(g, b)))
		//}
	}

	/// Resamples `source` into `self` using nearest-neighbor sampling
	public func resampleNearestNeighbor(from source: ImageBuffer<Luma>)
	{
		resampleNearestNeighbor(from: source.buffer, width: source.width, height: source.height)
	}

	/// Resamples `source` into `self` using nearest-neighbor sampling
	public func resampleNearestNeighbor(from source: UnsafeMutablePointer<Luma>, width: Int, height: Int)
	{
		nativeResampleNearestNeighborLuma(source, UInt32(width), UInt32(height), self.buffer, UInt32(self.width), UInt32(self.height))
	}

	/// Resamples `source` into `self` using fast estimation linear interpolation sampling
	public func resampleLerpFast(from source: ImageBuffer<Luma>)
	{
		resampleLerpFast(from: source.buffer, width: source.width, height: source.height)
	}

	/// Resamples `source` into `self` using fast estimation linear interpolation sampling
	public func resampleLerpFast(from source: UnsafeMutablePointer<Luma>, width: Int, height: Int)
	{
		nativeResampleLerpFastLuma(source, UInt32(width), UInt32(height), self.buffer, UInt32(self.width), UInt32(self.height))
	}
}

/// Specialization of ImageBuffer for Color samples
extension ImageBuffer where Sample == Color
{
	/// Initialize a new `ImageBuffer` from `source`
	///
	/// See `copy(from:width:height:)` for details on how the copy is performed
	///
	/// Throws:
	///		* ImageError.DimensionMismatch if `width` and `height` do not match this image
	public convenience init(_ source: ImageBuffer<Luma>) throws
	{
		self.init(width: source.width, height: source.height)
		try copy(from: source.buffer, width: source.width, height: source.height)
	}

	/// Initialize a new `ImageBuffer` from `source`
	///
	/// See `copy(from:width:height:)` for details on how the copy is performed
	public convenience init(_ source: ImageBuffer<Color>)
	{
		self.init(width: source.width, height: source.height)
		copy(from: source.buffer, width: source.width, height: source.height)
	}

	/// Copies image data from `source` into this `ImageBuffer`
	///
	/// See `copy(from:width:height:)` for details on how the copy is performed
	///
	/// Throws:
	///		* ImageError.DimensionMismatch if `width` and `height` do not match this image
	public func copy(from source: ImageBuffer<Luma>) throws
	{
		try copy(from: source.buffer, width: source.width, height: source.height)
	}

	/// Copies image data from `source` into this `ImageBuffer`
	///
	/// See `copy(from:width:height:)` for details on how the copy is performed
	///
	/// Note that if `width` and `height` do not match, a nearest-neighbor resample copy is performed
	public func copy(from source: ImageBuffer<Color>)
	{
		copy(from: source.buffer, width: source.width, height: source.height)
	}

	/// Copies `source` into `buffer`
	///
	/// The `source` image data is expanded into a monochrome image data during the copy
	///
	/// Note that `width` and `height` must match those within this `ImageBuffer`
	///
	/// Throws:
	///		* ImageError.DimensionMismatch if `width` and `height` do not match this image
	public func copy(from source: UnsafeMutablePointer<Luma>, width: Int, height: Int) throws
	{
		assert(self.width == width && self.height == height)
		if self.width != width || self.height != height
		{
			throw ImageError.DimensionMismatch
		}

		nativeCopyLumaToColor(source, buffer, UInt32(width), UInt32(height))

		//let count = width * height
		//for i in 0..<count
		//{
		//	let px = Color(source[i])
		//	buffer[i] = px | (px << 8) | (px << 16)// | 0xff000000
		//}
	}

	/// Copies `source` into `buffer`
	///
	/// As the types are matching, no conversion is performed and the image data is simply copied directly from `source`
	///
	/// Note that `width` and `height` must match those within this `ImageBuffer`
	///
	/// Note that if `width` and `height` do not match, a nearest-neighbor resample copy is performed
	public func copy(from source: UnsafeMutablePointer<Color>, width: Int, height: Int)
	{
		if self.width == width && self.height == height
		{
			buffer.initialize(from: source, count: width * height)
		}
		else
		{
			resampleNearestNeighbor(from: source, width: width, height: height)
		}
	}

	/// Resamples `source` into `self` using nearest-neighbor sampling
	public func resampleNearestNeighbor(from source: ImageBuffer<Color>)
	{
		resampleNearestNeighbor(from: source.buffer, width: source.width, height: source.height)
	}

	/// Resamples `source` into `self` using nearest-neighbor sampling
	public func resampleNearestNeighbor(from source: UnsafeMutablePointer<Color>, width: Int, height: Int)
	{
		nativeResampleNearestNeighborColor(source, UInt32(width), UInt32(height), self.buffer, UInt32(self.width), UInt32(self.height))
	}
}
