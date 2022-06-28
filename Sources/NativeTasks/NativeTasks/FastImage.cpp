//
//  FastImage.cpp
//  NativeTasks
//
//  Created by Paul Nettle on 3/1/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#include <algorithm>
#include "FastImage.h"
#include "Logger.h"

/// Copies image `src` (2vuy) to `dst` image (8-bit monochrome)
///
/// Note that both `src` is a 16-bit format and must contain at least `width` * `height` * `2` elements, while `dst` must contain at least `width` * `height` elements
void copy2vuyToLuma(const NativeLumaBuffer src, NativeLumaBuffer dst, uint32_t width, uint32_t height)
{
	uint32_t count = width * height;
	for (uint32_t i = 0; i < count; ++i)
	{
		dst[i] = src[i * 2 + 1];
	}
}

/// Copies image `src` (8-bit monochrome) to `dst` image (32-bit ARGB) with 8-bit -> 32-bit monochrome conversion
///
/// Note that both `src` and `dst` must contain at least `width` * `height` elements each
void copyLumaToColor(const NativeLumaBuffer src, NativeColorBuffer dst, uint32_t width, uint32_t height)
{
	uint32_t count = width * height;
	for (uint32_t i = 0; i < count; ++i)
	{
		uint32_t pix = uint32_t(src[i]);
		dst[i] = pix | (pix << 8) | (pix << 16); // | 0xff000000
	}
}

/// Copies image `src` (32-bit ARGB) to `dst` image (8-bit monochrome) with 32-bit -> 8-bit monochrome conversion
///
/// Note that both `src` and `dst` must contain at least `width` * `height` elements each
void copyColorToLuma(const NativeColorBuffer src, NativeLumaBuffer dst, uint32_t width, uint32_t height)
{
	uint32_t count = width * height;
	for (uint32_t i = 0; i < count; ++i)
	{
		uint32_t pix = src[i];
		dst[i] = uint8_t(std::max((pix>>16)&0xff, std::max((pix>>8)&0xff, pix&0xff)));
	}
}

/// Resamples 8-bit monochrome image `src` to `dst` with nearest-neighbor sampling
void resampleNearestNeighborLuma(const NativeLumaBuffer src, uint32_t srcWidth, uint32_t srcHeight, NativeLumaBuffer dst, uint32_t dstWidth, uint32_t dstHeight)
{
	// FixedPoint scale
	const int kFixedShift = 16;

	// Deltas (using kFixedShift for fixed-point calculations)
	int fxDxSrc = (srcWidth << kFixedShift) / dstWidth;
	int fxDySrc = (srcHeight << kFixedShift) / dstHeight;

	// Draw the image (with crude scaling) into the image buffer
	for (int yDst = 0, ySrc = 0; yDst < static_cast<int>(dstHeight); yDst += 1, ySrc += fxDySrc)
	{
		int yDstOffset = yDst * dstWidth;
		int ySrcOffset = (ySrc >> kFixedShift) * srcWidth;
		for (int xDst = 0, xSrc = 0; xDst < static_cast<int>(dstWidth); xDst += 1, xSrc += fxDxSrc)
		{
			int xDstOffset = xDst;
			int xSrcOffset = xSrc >> kFixedShift;
			dst[yDstOffset + xDstOffset] = src[ySrcOffset + xSrcOffset];
		}
	}
}

/// Resamples 32-bit Color image `src` to `dst` with nearest-neighbor sampling
void resampleNearestNeighborColor(const NativeColorBuffer src, uint32_t srcWidth, uint32_t srcHeight, NativeColorBuffer dst, uint32_t dstWidth, uint32_t dstHeight)
{
	// FixedPoint scale
	const int kFixedShift = 16;

	// Deltas (using kFixedShift for fixed-point calculations)
	int fxDxSrc = (srcWidth << kFixedShift) / dstWidth;
	int fxDySrc = (srcHeight << kFixedShift) / dstHeight;

	// Draw the image (with crude scaling) into the image buffer
	for (int yDst = 0, ySrc = 0; yDst < static_cast<int>(dstHeight); yDst += 1, ySrc += fxDySrc)
	{
		int yDstOffset = yDst * dstWidth;
		int ySrcOffset = (ySrc >> kFixedShift) * srcWidth;
		for (int xDst = 0, xSrc = 0; xDst < static_cast<int>(dstWidth); xDst += 1, xSrc += fxDxSrc)
		{
			int xDstOffset = xDst;
			int xSrcOffset = xSrc >> kFixedShift;
			dst[yDstOffset + xDstOffset] = src[ySrcOffset + xSrcOffset];
		}
	}
}

/// Resamples 8-bit monochrome image `src` to `dst` with fast estimation linear interpolation sampling
void resampleLerpFastLuma(const NativeLumaBuffer src, uint32_t srcWidth, uint32_t srcHeight, NativeLumaBuffer dst, uint32_t dstWidth, uint32_t dstHeight)
{
	// FixedPoint scale
	const int kFixedShift = 16;

	// Deltas through the source image in X and Y
	int dxSrc = (srcWidth << kFixedShift) / dstWidth;
	int dySrc = (srcHeight << kFixedShift) / dstHeight;

	// Loop through each line of the destination image
	for (int yDst = 0, ySrc = 0; yDst < static_cast<int>(dstHeight); yDst += 1, ySrc += dySrc)
	{
		int yDstOffset = yDst * dstWidth;

		int y0Src = ySrc >> kFixedShift;
		int y1Src = (ySrc + dySrc) >> kFixedShift;

		// Loop through each column of the destination image
		for (int xDst = 0, xSrc = 0; xDst < static_cast<int>(dstWidth); xDst += 1, xSrc += dxSrc)
		{
			int xDstOffset = xDst;

			int x0Src = xSrc >> kFixedShift;
			int x1Src = (xSrc + dxSrc) >> kFixedShift;

			// Loop through the src rect, tallying up the samples
			int pix = 0;
			for (int y = y0Src; y < y1Src; ++y)
			{
				int ySrcOffset = y * srcWidth;
				for (int x = x0Src; x < x1Src; ++x)
				{
					pix += src[ySrcOffset + x];
				}
			}

			int tot = (y1Src - y0Src) * (x1Src - x0Src);
			dst[yDstOffset + xDstOffset] = (LumaSample)(pix / tot);
		}
	}
}

/// Rotates an image by 180-degrees
///
/// This is an optimized method to flip the image horizontally and vertically in-place in a single pass
void rotate180(const NativeLumaBuffer buffer, uint32_t width, uint32_t height)
{
	uint32_t halfHeight = height / 2;
	uint32_t halfWidth = width / 2;
	for (uint32_t y = 0; y < halfHeight; y++)
	{
		LumaSample *topLine = buffer + width * y;
		LumaSample *botLine = buffer + width * (height - y - 1);
		for (uint32_t x = 0; x < halfWidth; ++x)
		{
			LumaSample ltmp = topLine[x];
			LumaSample rtmp = topLine[width - x - 1];
			topLine[x] = botLine[width - x - 1];
			topLine[width - x - 1] = botLine[x];
			botLine[x] = rtmp;
			botLine[width - x - 1] = ltmp;
		}
	}

	// let halfHeight = height / 2
	// let halfWidth = width / 2
	// for y in 0..<halfHeight
	// {
	// 	let topLine = buffer + width * y
	// 	let botLine = buffer + width * (height - y - 1)
	// 	for x in 0..<halfWidth
	// 	{
	// 		let ltmp = topLine[x]
	// 		let rtmp = topLine[width - x - 1]
	// 		topLine[x] = botLine[width - x - 1]
	// 		topLine[width - x - 1] = botLine[x]
	// 		botLine[x] = rtmp
	// 		botLine[width - x - 1] = ltmp
	// 	}
	// }
}
