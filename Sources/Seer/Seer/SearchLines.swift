//
//  SearchLines.swift
//  Seer
//
//  Created by Paul Nettle on 11/26/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
#if os(iOS)
import MinionIOS
#else
import Minion
#endif

// ---------------------------------------------------------------------------------------------------------------------------------
// Local constants
// ---------------------------------------------------------------------------------------------------------------------------------

/// Defines an image-space line used for searching the image for marks and patterns in the luma samples.
///
/// Search lines are generated from an originating location and direction (anchor and normal), and are then offset and rotated
/// incrementally in order to get screen coverage for deck searches.
///
/// The order in which these lines are used for searching is important for efficiency, so during this calculation, the lines are
/// weighted. The final set of lines use to search the deck are the weight-sorted list of SearchLines. For a more detailed
/// description of this process, see generateSearchLines() in DeckSearch.swift.
final class SearchLines
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// A convenience constant used for stepping the lines perpendicular to their original orientation
	private static let kStepNormal = Vector(x: 0, y: 1)

	/// A convenience constant representing the line's orientation
	private static let kScanNormal = Vector(x: 1, y: 0)

	// -----------------------------------------------------------------------------------------------------------------------------
	// Custom types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// A single search line
	struct SearchLine
	{
		/// The offset of this line from (0, 0)
		let offset: Real

		/// The angle of the line in degrees
		let angleDegrees: Real

		/// The weight of the line used for prioritizing search order
		let weight: Real

		/// Initializes a SearchLine from the base necessities
		init(offset: Real, angleDegrees: Real, weight: Real)
		{
			self.offset = offset
			self.angleDegrees = angleDegrees
			self.weight = weight
		}

		/// Returns a line from this SearchLine with a given origin, offsetLocation, offsetAngle and whose origin is within a given
		/// bufferRect.
		func getLine(origin: IVector, offsetLocation: IVector, offsetAngleDegrees: Real, bufferRect: Rect<Int>) -> SampleLine?
		{
			let totalRotationDegrees = angleDegrees + offsetAngleDegrees

			// Combined rotation of our scanning normal
			let scanNormal = SearchLines.kScanNormal.rotated(degrees: totalRotationDegrees)

			// Our local-space position
			var scanLocation = SearchLines.kStepNormal * offset

			// Rotate it
			scanLocation.rotate(degrees: totalRotationDegrees)

			// Move it into place
			scanLocation += origin.toVector() + offsetLocation.toVector()

			// Intersect it with the input rect and return the line

			let negVector = scanLocation.project(onto: bufferRect, along: -scanNormal)
			let posVector = scanLocation.project(onto: bufferRect, along: scanNormal)
			return SampleLine(line: Line(p0: negVector, p1: posVector))
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The collection of search lines used to scan an image
	private(set) var searchLines = [SearchLine]()

	/// The dimentions of the image used to generate the current set of search lines
	public let size: IVector

	/// The dimentions of the image used to generate the current set of search lines
	public let reversible: Bool

	/// Returns the number of search lines in the collection
	var count: Int { return searchLines.count }

	/// Returns the search line at the given index
	subscript(index: Int) -> SearchLine { return searchLines[index] }

	// Our previous config values that define our search lines so we can tell when they change
	private var prevSearchLineHorizontalWeightAdjustment: Real = 0
	private var prevSearchLineRotationDensity: Real = 0
	private var prevSearchLineRotationSteps: Real = 0
	private var prevSearchLineMinAngleCutoff: Real = 0
	private var prevSearchLineMaxAngleCutoff: Real = 0
	private var prevSearchLineLinearLimitScalar: Real = 0
	private var prevSearchLineLinearDensity: Real = 0
	private var prevSearchLineLinearSteps: Real = 0
	private var prevSearchLineBidirectional: Bool = false

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Generates a series of search lines that follow a prioritized ordering scheme for optimal deck location searches
	///
	/// The image is scanned starting at the 'origin' (by default, the center of the image) using a coarse pattern of search lines
	/// that radiate out and away from the origin. This process continues until a deck is located or the entire image area has been
	/// covered. Whenever a deck is found, the origin is moved to that location in order to take advantage of the temporal nature of
	/// tracking objects in video input.
	///
	/// The deck is generally assumed to have a tendency toward a horizontal orientation, but as this will not always be the case,
	/// off-axis (rotated) scans are included in the pattern. The order of these scans is decided by a priority-based heuristic.
	///
	/// The purpose of the heuristic is to answer the question: "What's more likely, A deck that is farther away from the origin,
	/// or one that is rotated off-axis a bit?"
	///
	/// GENERATING SEARCH LINES:
	///
	/// Each search line has an anchor point (which specifies its vertical offset from the origin) and an angle of rotation. As
	/// lines are moved or rotated, they do so in steps. Step amounts are chosen such that they allow coverage without requiring the
	/// scanning of every image sample. This is done carefully as step sizes are a trade-off of accuracy and speed.
	///
	/// A set of search lines is generated with anchor points that step vertically away from the origin in the positive and negative
	/// directions. it is important that enough search lines are generated to cover twice area of the image. This is the case
	/// because the origin may not be in the center of the image. For example, if the origin was moved to the negative extent, there
	/// would need to be enough positive search lines to cover the full height of the image.
	///
	/// Similar sets of search lines are also generated with for each step of rotation in the positive and negative directions.
	///
	/// In addition to this pattern, the step values increase with greater distance or angle. This allows for higher density
	/// scanning near the origin where the deck is most likely to be (see the note about temporal tracking above) without suffering
	/// that density for the entire image.
	///
	/// THE HEURISTIC:
	///
	/// Each search line is assigned a weight based on its distance from the origin and angle of rotation. Search lines that are
	/// farther from the origin and/or have a higher angle of rotation will receive larger weights.
	///
	/// Weights are balanced such that rotation receives a slightly higher weight than distance in order to provide a priority to
	/// horizontal scanning.
	///
	/// THE GOAL:
	///
	/// The final outcome should resemble the following. Note that the list below is a set of offset steps (offStep) distance from
	/// the origin and rotational steps (rotStep) rotations from horizontal. In this example, there are only two rotational steps.
	///
	///     0.  Start at the origin, the horizontal search line is scanned (offStep 0, rotStep 0)
	///     1.  (offStep 1, rotStep 0)
	///     2.  (offStep 2, rotStep 0)
	///     3.  (offStep 0, rotStep 1)
	///     4.  (offStep 3, rotStep 0)
	///     5.  (offStep 4, rotStep 0)
	///     6.  (offStep 0, rotStep 2)
	///     7.  (offStep 5, rotStep 0)
	///     8.  (offStep 6, rotStep 0)
	///     9.  (offStep 1, rotStep 1)
	///     10. (offStep 6, rotStep 0)
	///     11. (offStep 7, rotStep 0)
	///     12. (offStep 1, rotStep 2)
	///     13. (offStep 8, rotStep 0)
	///     14. (offStep 9, rotStep 0)
	///     15. (offStep 2, rotStep 1)
	///     ...
	///
	/// Note that the #1 and #2 take place with no rotation, simply stepping vertically away from the origin. However, at #3, the
	/// weight of rotation finally overcomes the weight of distance and a single step of rotation is made (back at the origin:
	/// offStep 0). Scanning then proceeds to step further from the origin until once again the distance is too great and the weight
	/// of the second rotational step at the origin finally overcomes the weight of distance. You can see this pattern continue,
	/// eventually allowing rotation in offset steps 1 and 2.
	///
	/// Although this pattern seems simple, using a heuristic allows us the flexibility to do quite a lot to control the importance
	/// of offset versus rotation. We could, for example, make the weights non-linear by squaring them. We could scale them relative
	/// to each other such that the farther distances from the origin balance the weight scale and allow for more rotation (or the
	/// opposite.) There are plenty of options here.
	init(size: IVector, reversible: Bool = false)
	{
		let kMinAngleCutoff = Config.searchLineMinAngleCutoff
		let kMaxAngleCutoff = Config.searchLineMaxAngleCutoff

		let kLinearLimitScalar = Config.searchLineLinearLimitScalar
		let kBidirectional = Config.searchLineBidirectional

		let kLinearDensity = Config.searchLineLinearDensity
		let kLinearSteps = Config.searchLineLinearSteps

		let kRotationDensity = Config.searchLineRotationDensity
		let kRotationSteps = Config.searchLineRotationSteps

		assert(kLinearDensity >= 1)
		assert(kRotationDensity >= 1)
		assert(kLinearSteps >= 1)
		assert(kRotationSteps >= 1)

		self.size = size
		self.reversible = reversible
		searchLines.reserveCapacity(self.size.y)

		// Our curve functions
		let expFunc = expFactory(k: kLinearDensity)
		let sigmoidFunc = sigmoidFactory(k: kRotationDensity)

		// Our offset range is just enough to cover the full distance from the center to max(width,height) of the image
		let offsetRange = Real(self.size.max() / 2) * kLinearLimitScalar
		for offsetScalar in stride(from: Real(0), to: Real(1), by: 1.0 / kLinearSteps)
		{
			let offsetExp = expFunc(offsetScalar)
			let offset = offsetExp * offsetRange

			let kAngleRange: Real = 90.0
			for angleScalar in stride(from: Real(0), to: Real(1), by: 1.0 / kRotationSteps)
			{
				let angleSigmoid = sigmoidFunc(angleScalar)
				let angleDegrees = angleSigmoid * kAngleRange

				// Limit our angle with cut-offs
				if angleDegrees < kMinAngleCutoff { continue }
				if angleDegrees > kMaxAngleCutoff { break }

				// Calculate the weight, which is just the sum of the homogenized offset and angle
				let weight = abs(offsetExp) + abs(angleSigmoid) * Config.searchLineHorizontalWeightAdjustment

				// Note that we disable bidirectionality if the deck is reversible. This is because a reversible deck might
				// be flipped upside down and we need to know which way is up!
				let bidirSet = (kBidirectional && !reversible) ? [Real(0), Real(180)] : [Real(0)]
				for bidirRot in bidirSet
				{
					for rotDir in [Real(1), Real(-1)]
					{
						if angleDegrees == 0 && rotDir == -1 { continue }
						for offDir in [Real(1), Real(-1)]
						{
							if offset == 0 && offDir == -1 { continue }
							searchLines.append(SearchLine(offset: offset * offDir, angleDegrees: (angleDegrees + bidirRot) * rotDir, weight: weight))
						}
					}
				}
			}
		}

		// Sort the lines by weight
		searchLines.sort { $0.weight < $1.weight }

		// Filter out lines that are too similar
		let origin = IVector(x: size.x / 2, y: size.y / 2)
		let offset = IVector(x: 0, y: 0)
		let rect = Rect<Int>(minX: 0, minY: 0, maxX: size.x, maxY: size.y)
		var i = 0
		while i < searchLines.count
		{
			guard let baseLine = searchLines[i].getLine(origin: origin, offsetLocation: offset, offsetAngleDegrees: 0, bufferRect: rect) else { continue }
			let baseNormal = baseLine.vector.toVector().normal()
			let baseCenter = baseLine.center.toVector()
			var j = i + 1
			while j < searchLines.count
			{
				guard let compareLine = searchLines[j].getLine(origin: origin, offsetLocation: offset, offsetAngleDegrees: 0, bufferRect: rect) else { continue }
				let compareNormal = compareLine.vector.toVector().normal()
				let compareCenter = compareLine.center.toVector()

				let angleDelta = (Real(1) - (baseNormal ^ compareNormal)) * 90
				let dist = baseCenter.distance(to: compareCenter)

				if angleDelta < 0.5 && dist < 10
				{
					searchLines.remove(at: j)
				}
				else
				{
					j += 1
				}
			}

			i += 1
		}

		// Calculate how many lines to scan the typical image
		let typicalLineCount = debugCountSearchGrid(searchLines: searchLines, bufferRect: Rect<Int>(x: 0, y: 0, width: self.size.x, height: self.size.y))
		gLogger.search("Typical number of lines in search grid: \(typicalLineCount)")

		// Cache our configuration state so we can quickly determine if/when this SearchLines becomes outdated
		cacheConfiguration()
	}

	/// Tracks the current state of our search lines so we'll know if the config changes and requires a new set
	private func cacheConfiguration()
	{
		prevSearchLineHorizontalWeightAdjustment = Config.searchLineHorizontalWeightAdjustment
		prevSearchLineRotationDensity = Config.searchLineRotationDensity
		prevSearchLineRotationSteps = Config.searchLineRotationSteps
		prevSearchLineMinAngleCutoff = Config.searchLineMinAngleCutoff
		prevSearchLineMaxAngleCutoff = Config.searchLineMaxAngleCutoff
		prevSearchLineLinearLimitScalar = Config.searchLineLinearLimitScalar
		prevSearchLineLinearDensity = Config.searchLineLinearDensity
		prevSearchLineLinearSteps = Config.searchLineLinearSteps
		prevSearchLineBidirectional = Config.searchLineBidirectional
	}

	// Determines if the any of the search line configuration data has changed so that we can generate a new set when needed
	public func isOutdated(size: IVector, reversible: Bool = false) -> Bool
	{
		if size != self.size { return true }
		if reversible != self.reversible { return true }
		if Config.searchLineHorizontalWeightAdjustment != prevSearchLineHorizontalWeightAdjustment { return true }
		if Config.searchLineRotationDensity != prevSearchLineRotationDensity { return true }
		if Config.searchLineRotationSteps != prevSearchLineRotationSteps { return true }
		if Config.searchLineMinAngleCutoff != prevSearchLineMinAngleCutoff { return true }
		if Config.searchLineMaxAngleCutoff != prevSearchLineMaxAngleCutoff { return true }
		if Config.searchLineLinearLimitScalar != prevSearchLineLinearLimitScalar { return true }
		if Config.searchLineLinearDensity != prevSearchLineLinearDensity { return true }
		if Config.searchLineLinearSteps != prevSearchLineLinearSteps { return true }
		if Config.searchLineBidirectional != prevSearchLineBidirectional { return true }

		return false
	}

	func sigmoidFactory(k: Real) -> ((Real) -> Real)
	{
		func base(t: Real) -> Real
		{
			return (1 / (1 + Real(exp(-k * t)))) - 0.5
		}

		let correction = Real(0.5) / base(t: 1)

		let function: (Real) -> Real =
		{ t in
			let tc = max(min(t, Real(1)), Real(0))
			return correction * base(t: Real(2) * tc - Real(1)) + Real(0.5)
		}

		return function
	}

	func expFactory(k: Real) -> ((Real) -> Real)
	{
		let function: (Real) -> Real =
		{ t in
			let tc = max(min(t, Real(1)), Real(0))
			return pow(tc, k)
		}

		return function
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Debug
	// -----------------------------------------------------------------------------------------------------------------------------

	private func debugCountSearchGrid(searchLines: [SearchLine], bufferRect: Rect<Int>) -> Int
	{
		let center = bufferRect.center.roundToPoint()
		var count = 0
		for i in 0..<searchLines.count
		{
			let line = searchLines[i]
			if line.getLine(origin: center, offsetLocation: IVector(), offsetAngleDegrees: 0, bufferRect: bufferRect) == nil { continue }
			count += 1
		}
		return count
	}
}
