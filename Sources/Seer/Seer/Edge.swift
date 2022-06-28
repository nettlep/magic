//
//  Edge.swift
//  Seer
//
//  Created by Paul Nettle on 11/16/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// Defines an edge. That is, the point at which an edge is detected within an image
struct Edge
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The sample offset (within the original SampleLine) where this edge was detected
	private(set) var sampleOffset: Int

	/// A unit scalar representing the location of this edge within the CodeDefinition
	private(set) var normalizedLocation: Real

	/// The slope (sample delta) where the edge was detected
	let slope: RollValue

	/// The edge threshold that was used to detect the edge
	let threshold: RollValue

	/// The point within the image where this edge was detected
	let point: IVector

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a blank edge
	@inline(__always) init()
	{
		sampleOffset = 0
		normalizedLocation = 0
		slope = 0
		threshold = 0
		point = IVector()
	}

	/// Initialize an edge from its components
	///
	/// Note that the edge is not normalized (see normalize())
	@inline(__always) init(slope: RollValue, sampleOffset: Int, threshold: RollValue, point: IVector)
	{
		self.slope = slope
		self.threshold = threshold
		self.sampleOffset = sampleOffset
		self.normalizedLocation = 0
		self.point = point
	}

	/// Initialize an edge from its components, calculating `point` from the `sampleLine` and `sampleOffset`
	///
	/// Note that the edge is not normalized (see normalize())
	@inline(__always) init(slope: RollValue, sampleOffset: Int, threshold: RollValue, sampleLine: SampleLine)
	{
		self.slope = slope
		self.threshold = threshold
		self.sampleOffset = sampleOffset
		self.normalizedLocation = 0
		self.point = sampleLine.interpolationPoint(sampleOffset: sampleOffset)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Normalization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Normalize the edge by calculating `normalizedOffset` as a unit scalar to within the given range.
	///
	/// The range is specified by the starting point of a line and the length of that line. It is assumed that `point` is on that
	/// line.
	///
	/// Using the distance between `point` and `start`, the results are such that:
	///
	///    if the distance == 0, the result will be 0.0
	///    if the distance == length, the result will be 1.0
	@inline(__always) mutating func normalize(start: Vector, length: Real)
	{
		normalizedLocation = point.toVector().distance(to: start) / length
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension Edge: CustomStringConvertible, CustomDebugStringConvertible
{
	var debugDescription: String
	{
		return description
	}

	var description: String
	{
		return "offset[\(sampleOffset)] slope[\(slope)] location[\(String(describing: point))]"
	}
}
