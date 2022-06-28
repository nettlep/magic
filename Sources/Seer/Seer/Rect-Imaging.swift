//
//  Rect-Imaging.swift
//  Seer
//
//  Created by Paul Nettle on 3/31/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

// -----------------------------------------------------------------------------------------------------------------------------
// Drawing
// -----------------------------------------------------------------------------------------------------------------------------

/// A rectangle, defined with inclusive Min/Max values for X and Y
extension Rect where T == Int
{
	/// Fills a rectangular region of the image with a given color
	public func fill(to image: DebugBuffer?, color: Color)
	{
		if let image = image
		{

			if let r = intersected(with: image.rect)
			{
				let samples = image.buffer
				let width = image.width

				// Requires alpha blending?
				if ((color >> 24) & 0xff) != 0xff
				{
					for y in r.minY...r.maxY
					{
						let buf = samples + y * width
						for x in r.minX...r.maxX
						{
							buf[x] = alphaBlend(src: color, dst: buf[x])
						}
					}
				}
					// Does not require alpha blending
				else
				{
					for y in r.minY...r.maxY
					{
						let buf = samples + y * width
						for x in r.minX...r.maxX
						{
							buf[x] = color
						}
					}
				}
			}
		}
	}

	/// Draws a rectangular outline specified by a pair of X and Y extents (`x0`-`x1`, `y0`-`y1`) with a given `padding` and
	/// `thickness` in the specified `color`.
	///
	/// The rectangle will cover all samples [`x0`, `x1`] and [`y0`, `y1`]. If `thickness` is > 1, then the additional outline
	/// samples will be drawn. If `inset` is > 0, then `inset` samples will be skipped before drawing `thickness` outlines.
	///
	/// The order of `x0`, `x1` and `y0`, `y1` determine the direction in which `thickness` and `padding` extend. This only matters
	/// if `thickness` > 1 or `padding` > 0. `x0` < `x1` and `y0` < `y1`, then the `thickness` and `padding` will extend inward
	/// towards the center of the rectangle. Otherwise, they will extend outward in the direction of the swapped components. For
	/// clarity, passing in a set of extents such that `x0` < `x1` and `y0` > `y1` will cause `thickness` and `padding` to extend
	/// inward in the X direction and outward in the Y direction.
	public func outline(to image: DebugBuffer?, color: Color, thickness: T = 1, padding: T = 0)
	{
		// Make a copy of our rect, reduced by padding
		var r = reduced(by: padding)

		// Our routines fill all samples, so our thickness needs to be reduced by a single sample
		let thick = thickness - 1

		// Draw the top rect
		Rect(minX: r.minX, minY: r.minY, maxX: r.maxX, maxY: r.minY + thick).fill(to: image, color: color)

		// Draw the bottom rect
		Rect(minX: r.minX, minY: r.maxY - thick, maxX: r.maxX, maxY: r.maxY).fill(to: image, color: color)

		// Adjust reduce our Y range to account for the samples we just filled with the top/bottom rects
		r.minY += thick + 1
		r.maxY -= thick + 1

		// Draw the left rect
		Rect(minX: r.minX, minY: r.minY, maxX: r.minX + thick, maxY: r.maxY).fill(to: image, color: color)

		// Draw the right rect
		Rect(minX: r.maxX - thick, minY: r.minY, maxX: r.maxX, maxY: r.maxY).fill(to: image, color: color)
	}
}
