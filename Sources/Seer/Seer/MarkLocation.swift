//
//  MarkLocation.swift
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

/// Defines a mark as detected within an image.
///
/// A mark is a dark portion of the image surrounded by two edges (start and end). Note that the start Edge should
/// reference the first sample of the mark, and the end Edge should reference the last sample of the mark. When getting
/// the sample width of the mark, the total number of samples that the mark occupies will be returned.
public struct MarkLocation
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The starting Edge of the mark (the first sample of the mark)
	private(set) var start: Edge

	/// The ending Edge of the mark (the final sample of the mark)
	private(set) var end: Edge

	/// The index of this mark within the set that was originally scanned along the search line while searching for a deck.
	///
	/// Note that some DeckLocations (those after having been matched to a CodeDefinition) may contain a set of MarkLocations
	/// whose scanIndexes are ordered, but not consecutive.
	private(set) var scanIndex: Int

	/// The index of a MarkDefinition within the CodeDefinition to which this mark has been matched.
	///
	/// Note that this index is only valid after the DeckLocation has been matched to a CodeDefinition. Prior to that point, they
	/// will be set to -1.
	var matchedDefinitionIndex: Int

	/// Returns the complete number of samples that this mark occupies
	var sampleCount: Int { return end.sampleOffset - start.sampleOffset + 1 }

	/// Returns the center point of the mark
	///
	/// As this is an integer operation, the result may not be exact. In these cases, the X/Y component will lean toward zero.
	var center: IVector { return (end.point + start.point) / 2 }

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a mark from two edges, an index and an (optional) matchedDefinitionIndex
	@inline(__always) init(start: Edge, end: Edge, scanIndex: Int, matchedDefinitionIndex: Int = -1)
	{
		self.start = start
		self.end = end
		self.scanIndex = scanIndex
		self.matchedDefinitionIndex = matchedDefinitionIndex
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Normalization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Normalize the mark to a given range
	@inline(__always) mutating func normalize(from start: IVector, to end: IVector)
	{
		let vStart = start.toVector()
		let length = vStart.distance(to: end.toVector())
		self.start.normalize(start: vStart, length: length)
		self.end.normalize(start: vStart, length: length)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Debug
	// -----------------------------------------------------------------------------------------------------------------------------

	func debugDrawOverlay(image: DebugBuffer?, color: Color? = nil)
	{
		let start = self.start.point.toVector()
		let end = self.end.point.toVector()
		let perp = (end - start).rotated(degrees: 90).ofLength(Real(25 * image!.height / 720))

		// Draw a box around the mark
		let sp0 = start - perp
		let sp1 = start + perp
		let ep0 = end - perp
		let ep1 = end + perp
		SampleLine(line: Line(p0: sp1, p1: ep1)).draw(to: image, color: color ?? kDebugMarkLocationLineColor)
		SampleLine(line: Line(p0: ep1, p1: ep0)).draw(to: image, color: color ?? kDebugMarkLocationLineColor)
		SampleLine(line: Line(p0: ep0, p1: sp0)).draw(to: image, color: color ?? kDebugMarkLocationLineColor)
		SampleLine(line: Line(p0: sp0, p1: sp1)).draw(to: image, color: color ?? kDebugMarkLocationLineColor)
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension MarkLocation: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		return "samples[\(sampleCount)] start[\(String(describing: start))] end[\(String(describing: end))]"
	}
}
