//
//  IVector-Imaging.swift
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

/// Extensions for drawing points via an IVector
extension IVector
{
	/// Sets the color of the sample to `color` a point at the position represented by the (x, y)
	public func draw(to image: DebugBuffer?, color: Color)
	{
		if let samples = image?.buffer
		{
			if !image!.rect.contains(point: self) { return }

			samples[y * image!.width + x] = alphaBlend(src: color, dst: samples[y * image!.width + x])
		}
	}
}
