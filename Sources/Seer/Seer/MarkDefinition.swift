//
//  MarkDefinition.swift
//  Seer
//
//  Created by Paul Nettle on 11/17/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// A MarkDefinition defines a mark printed on the deck within a CodeDefinition.
///
/// A mark is defined by a type (ex: Landmark, Space, Bit) and a position (start, width) within the CodeDefinition. A full
/// set of contiguous marks define a CodeDefinition.
///
/// Mark dimensions are measured in millimeters but are also normalized to the entire CodeDefinition's width so that the entire
/// set of marks fill the range from [0...1].
public struct MarkDefinition
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The type of this mark (ex: Landmark, Space, Bit)
	public let type: MarkType

	/// The index of this MarkDefinition within the CodeDefinition
	public let index: Int

	/// The start of the mark (in millimeters) relative to the start of the CodeDefinition
	public let startMM: Real

	/// The width of the mark (in millimeters) to the start of the CodeDefinition
	public let widthMM: Real

	/// The end of the mark (in millimeters)
	public var endMM: Real { return startMM + widthMM }

	/// The end of the mark (in millimeters)
	public var centerMM: Real { return (startMM + endMM) / 2}

	/// Unit normal representing the start of this mark within the range of the CodeDefinition
	public private(set) var normalizedStart: Real = 0.0

	/// Unit normal representing the width of this mark within the range of the CodeDefinition
	public private(set) var normalizedWidth: Real = 0.0

	/// Unit normal representing the end of this mark (and the start of the next) within the range of the CodeDefinition
	public var normalizedEnd: Real { return normalizedStart + normalizedWidth }

	/// Unit normal representing the normalized center of this mark within the range of the CodeDefinition
	public var normalizedCenter: Real { return (normalizedStart + normalizedEnd) / 2 }

	/// This represents half of the minimum distance between this mark and its neighboring spaces. It is stored as a ratio of the
	/// width of this mark.
	///
	/// The calculation of this value requires that this is a Landmark and there is a Space before and after it. Otherwise, this
	/// value will be zero.
	///
	/// Disclaimer: This is intended for use in the search process' TraceMarks (precalculated here for convenience.)
	public var landmarkMinGapRatio: FixedPoint = 0

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a mark of a given type along with a start and width (in millimeters)
	init(type: MarkType, index: Int, startMM: Real, widthMM: Real)
	{
		self.type = type
		self.index = index
		self.startMM = startMM
		self.widthMM = widthMM
	}

	/// Initialize a MarkDefinition from another MarkDefinition
	init(markDefinition: MarkDefinition)
	{
		self.type = markDefinition.type
		self.index = markDefinition.index
		self.startMM = markDefinition.startMM
		self.widthMM = markDefinition.widthMM
		self.normalizedStart = markDefinition.normalizedStart
		self.normalizedWidth = markDefinition.normalizedWidth
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Normalization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Normalize a MarkDefinition to a given width.
	///
	/// This is generally used to normalize a mark to the dimensions of a CodeDefinition. See properties `normalizeStart` and
	/// `normalizeEnd` for more information.
	mutating func normalize(to widthMM: Real)
	{
		normalizedStart = self.startMM / widthMM
		normalizedWidth = self.widthMM / widthMM
	}
	// -----------------------------------------------------------------------------------------------------------------------------
	// Debug
	// -----------------------------------------------------------------------------------------------------------------------------

	func debugDrawOverlay(image: DebugBuffer?, deckReference deckLocation: DeckLocation)
	{
		let sampleLine = deckLocation.sampleLine
		let startOffset = (normalizedStart * Real(sampleLine.interpolatedLength)).roundToNearest()
		let endOffset = (normalizedEnd * Real(sampleLine.interpolatedLength)).roundToNearest()
		let start = sampleLine.interpolationPoint(sampleOffset: startOffset).toVector()
		let end = sampleLine.interpolationPoint(sampleOffset: endOffset).toVector()
		let center = (start + end) / Real(2)
		let height = type.isLandmark ? 25 : 10
		let perp = (sampleLine.p1.toVector() - sampleLine.p0.toVector()).rotated(degrees: 90).ofLength(Real(height * image!.height / 720))

		// Draw the diamond on the mark definition range
		let midPointA = center - perp
		SampleLine(line: Line(p0: start, p1: midPointA)).draw(to: image, color: kDebugMarkDefinitionLineColor)
		SampleLine(line: Line(p0: end, p1: midPointA)).draw(to: image, color: kDebugMarkDefinitionLineColor)

		let midPointB = center + perp
		SampleLine(line: Line(p0: start, p1: midPointB)).draw(to: image, color: kDebugMarkDefinitionLineColor)
		SampleLine(line: Line(p0: end, p1: midPointB)).draw(to: image, color: kDebugMarkDefinitionLineColor)

		SampleLine(line: Line(p0: midPointA, p1: midPointB)).draw(to: image, color: kDebugMarkDefinitionLineColor)
	}
}
