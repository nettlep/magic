//
//  FastImage.h
//  NativeTasks
//
//  Created by Paul Nettle on 5/22/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#pragma once

#include "include/NativeTaskTypes.h"

/// Copies image `src` (2vuy) to `dst` image (8-bit monochrome)
///
/// Note that both `src` is a 16-bit format and must contain at least `width` * `height` * `2` elements, while `dst` must contain at least `width` * `height` elements
void copy2vuyToLuma(const NativeLumaBuffer src, NativeLumaBuffer dst, uint32_t width, uint32_t height);

/// Copies image `src` (8-bit monochrome) to `dst` image (32-bit ARGB) with 8-bit -> 32-bit monochrome conversion
///
/// Note that both `src` and `dst` must contain at least `width` * `height` elements each
void copyLumaToColor(const NativeLumaBuffer src, NativeColorBuffer dst, uint32_t width, uint32_t height);

/// Copies image `src` (32-bit ARGB) to `dst` image (8-bit monochrome) with 32-bit -> 8-bit monochrome conversion
///
/// Note that both `src` and `dst` must contain at least `width` * `height` elements each
void copyColorToLuma(const NativeColorBuffer src, NativeLumaBuffer dst, uint32_t width, uint32_t height);

/// Resamples 8-bit monochrome image `src` to `dst` with nearest-neighbor sampling
void resampleNearestNeighborLuma(const NativeLumaBuffer src, uint32_t srcWidth, uint32_t srcHeight, NativeLumaBuffer dst, uint32_t dstWidth, uint32_t dstHeight);

/// Resamples 32-bit Color image `src` to `dst` with nearest-neighbor sampling
void resampleNearestNeighborColor(const NativeColorBuffer src, uint32_t srcWidth, uint32_t srcHeight, NativeColorBuffer dst, uint32_t dstWidth, uint32_t dstHeight);

/// Resamples 8-bit monochrome image `src` to `dst` with fast estimation linear interpolation sampling
void resampleLerpFastLuma(const NativeLumaBuffer src, uint32_t srcWidth, uint32_t srcHeight, NativeLumaBuffer dst, uint32_t dstWidth, uint32_t dstHeight);

/// Rotates an image by 180-degrees
///
/// This is an optimized method to flip the image horizontally and vertically in-place in a single pass
void rotate180(const NativeLumaBuffer buffer, uint32_t width, uint32_t height);
