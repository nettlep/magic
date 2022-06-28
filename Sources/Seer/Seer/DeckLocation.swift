//
//  DeckLocation.swift
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

/// Represents a deck that was found while searching an image for a given CodeDefinition.
///
/// The representation comes in the form of a set of MarkType.Landmark MarkLocations, denoting the actual positions within the
/// deck where each mark was found.
public final class DeckLocation
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The set of MarkLocations that were found in the image. These will be for marks defined as MarkType.Landmark
	private(set) var markLocations: [MarkLocation]

	/// Returns the line covering the samples of the found deck
	let sampleLine: SampleLine

	/// Returns the number of MarkLocations
	var markCount: Int { return markLocations.count }

	/// Returns the first sample occupied by the found deck. This will be the first sample of the first MarkLocation
	var sampleStart: Int { assert(markCount > 0); return markLocations.first!.start.sampleOffset }

	/// Returns the last sample occupied by the found deck. This will be the last sample of the last MarkLocation
	var sampleEnd: Int { assert(markCount > 0); return markLocations.last!.end.sampleOffset }

	/// Returns the number of samples occupied by the found deck
	var sampleCount: Int { assert(markCount > 0); return sampleEnd - sampleStart + 1 }

	/// The first point of the first mark location
	var start: IVector { return sampleLine.p0 }

	/// The last point of the last mark location
	var end: IVector { return sampleLine.p1 }

	/// The length of this DeckLocation
	var length: Real { return start.toVector().distance(to: end.toVector()) }

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a DeckLocation from an array of MarkLocations
	init(markLocations: [MarkLocation])
	{
		assert(markLocations.count > 0)

		self.markLocations = markLocations
		sampleLine = SampleLine(p0: markLocations.first!.start.point, p1: markLocations.last!.end.point)

		normalize(from: start, to: end)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Normalizes all MarkLocations to the full range of this DeckLocation
	///
	/// See normalize(from:to:) for important implementation details.
	func normalize()
	{
		normalize(from: start, to: end)
	}

	/// Normalizes all MarkLocations to the given start and end points.
	///
	/// Note that the start and end points should define a line that is co-linear with the points of the Edges of the MarkLocations
	/// in this DeckLocation.
	func normalize(from start: IVector, to end: IVector)
	{
		for i in 0..<markLocations.count
		{
			markLocations[i].normalize(from: start, to: end)
		}
	}

	/// Locates a MarkLocation based on its definition index
	///
	/// To locate the index of the MarkLocation (rather than the MarkLocation itself) see `findMarkLocationIndex(index:)`
	///
	/// This is useful for locating MarkLocations that represent a specific MarkDefinition within the CodeDefinition
	public func findMarkLocation(forMatchDefinitionIndex index: Int) -> MarkLocation?
	{
		if let mlIndex = findMarkLocationIndex(forMatchDefinitionIndex: index)
		{
			return markLocations[mlIndex]
		}
		return nil
	}

	/// Locates a MarkLocation (by index) based on its definition index
	///
	/// To locate the MarkLocation itself (rather than its index) see `findMarkLocation(index:)`
	///
	/// This is useful for locating MarkLocations that represent a specific MarkDefinition within the CodeDefinition
	public func findMarkLocationIndex(forMatchDefinitionIndex index: Int) -> Int?
	{
		let end = markLocations.count
		for i in 0..<end
		{
			if markLocations[i].matchedDefinitionIndex == index { return i }
		}
		return nil
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension DeckLocation: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		var desc = "Deck width[\(sampleCount)] count[\(markCount)]:"
		for i in 0..<markCount
		{
			desc += "\(String.kNewLine)  \(i)[\(String(describing: markLocations[i]))]"
		}
		return desc
	}

	func debugDrawOverlay(image: DebugBuffer?, color: Color? = nil)
	{
		assert(markCount > 0)

		// Draw our marks
		for markLocation in markLocations
		{
			markLocation.debugDrawOverlay(image: image, color: kDebugMatchedMarkLocationLineColor)
		}

		// Draw the DeckLocation range
		let perp = sampleLine.perpOrthoNormal
		for i in -1...1
		{
			(sampleLine + perp * i).draw(to: image, color: color ?? kDebugDeckLocationRangeColorNormal)
		}
	}
}
