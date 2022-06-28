//
//  Debug.swift
//  Seer
//
//  Created by Paul Nettle on 11/18/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

// ---------------------------------------------------------------------------------------------------------------------------------
// Constants (debug colors and drawing values)
// ---------------------------------------------------------------------------------------------------------------------------------

/// The full line where the deck was not found
let kDebugSearchLineColor: Color = 0xf0ff0000

/// The line color when drawing the full grid
let kDebugSearchGridLineColor: Color = 0xf000ff00

/// The line color for the sequential search line feature
let kDebugSequentialSearchLineColor: Color = 0xffffff00

/// The range of the DeckLocation
let kDebugDeckLocationRangeColorNormal: Color = 0x40ff0000

/// The range of the DeckLocation (alternate color for things like discarded decks)
let kDebugDeckLocationRangeColorAlternate: Color = 0xa0800000

/// The range of the DeckLocation (discarded due to bad width)
let kDebugDeckLocationRangeColorBadWidth: Color = 0xa0606060

/// The range of the DeckLocation (discarded due to bad height)
let kDebugDeckLocationRangeColorBadHeight: Color = 0xa0a06060

/// Color of MarkDefinition lines
let kDebugMarkDefinitionLineColor: Color = 0x60ffff00

/// Color of normalized mark line locations
let kDebugNormalizedMarkLineColor: Color = 0xffffffff

/// Color of normalized mark line locations
let kDebugDeckLocationNormalizedMarkLineColor: Color = 0x80a08090

/// The marks that were found and used in a potential deck
let kDebugMarkLocationLineColor: Color = 0xffffffff

/// The marks that were found but not used in a potential deck
let kDebugUnusedMarkLocationLineColor: Color = 0x60ffffff

/// The marks chosen to match a deck
let kDebugMatchedMarkLocationLineColor: Color = 0xa000ff00

/// The lines that denote the location of bits in the deck
let kDebugMarkLineColor: Color = 0xff00ff00

/// The lines that denote the location of bits in the deck
let kDebugMarkBitColor: Color = 0xffff0000

/// The lines that define the deck extents for the marks
let kDebugDeckExtentsMarkLineColor: Color = 0xff0080ff

/// The lines that define the deck extents for the entire deck
let kDebugDeckExtentsDeckLineColor: Color = 0xff00ff00

/// The thickness of the outline border around the screen for decode feedback
let kDebugDecodeOutlineThickness: Int = 15

/// The lines that outline the frame for a deck that is found, but is too small
let kDeckSearchTooSmallBorderColor: Color = 0x80ffff00

/// The lines that outline the frame for a deck that is found, but extents could not be identified
let kDeckSearchNoExtentsBorderColor: Color = 0x80ff0000

/// The lines that outline the frame for a deck that is found
let kDeckSearchFoundBorderColor: Color = 0xff00ff00

/// The lines that outline the frame for a deck with low overall sharpness
let kDebugDecodeNotSharpBorderColor: Color = 0x40000000

/// The lines that outline the frame for a deck that decoded with too few cards
let kDebugDecodeTooFewCardsBorderColor: Color = 0xff004000

/// The lines that outline the frame for a general failure found during decoding
let kDebugDecodeGeneralFailureBorderColor: Color = 0xff000000

/// The lines that outline the frame for a deck when the resolve process fails
let kDebugDecodeDecodedBorderColor: Color = 0xff00ff00

/// The lines that outline the frame for a perfect deck
let kDebugDecodeValidationPerfectBorderColor: Color = 0xff008000

/// The lines that outline the frame for a failed deck
let kDebugDecodeValidationFailedBorderColor: Color = 0xff800000

/// The lines that outline the frame for a correct answer
let kDebugDecodeCorrectAnswerBorderColor: Color = 0x4000ff00

/// The lines that outline the frame for an incorrect answer
let kDebugDecodeIncorrectAnswerBorderColor: Color = 0x40ff0000

/// The color of the correctness factor bar
let kDebugDecodeLowConfidenceFactorBarColor: Color = 0x80ff0000

/// The color of the correctness factor bar
let kDebugDecodeHighConfidenceFactorBarColor: Color = 0xffff0000

/// The color of the correct % bar
let kDebugDecodeCorrectPercentBarColor: Color = 0xffff0000

/// Color for the centers of landmarks that are traced to find the deck extents
let kDebugSearchDeckExtentsLandmarkCenterColor: Color = 0xff0000ff

/// Color for the sample lines used to trace the landmarks
let kDebugSearchDeckExtentsLandmarkSampleLineColor: Color = 0x700080ff

/// Color for the adjustment range of landmarks that are traced to find the deck extents
let kDebugSearchDeckExtentsLandmarkAdjustmentRangeColor: Color = 0x80800000

// ---------------------------------------------------------------------------------------------------------------------------------
// Global functions
// ---------------------------------------------------------------------------------------------------------------------------------

/// Debug tool for checking if the user has requested a breakpoint. Insert this into your code, then hit the 'b' key
/// to break at the location this method is called
@inline(__always) public func checkBreakpoint()
{
	let shouldBreak = Config.debugBreakpointEnabled
	if shouldBreak
	{
		Config.debugBreakpointEnabled = false
		raise(SIGINT)
	}
}

/// Returns the version control revision that the app was built from
public func getRevision() -> String
{
	return SeerVersion
}
