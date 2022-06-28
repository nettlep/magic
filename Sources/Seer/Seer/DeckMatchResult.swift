//
//  DeckMatchResult.swift
//  Seer
//
//  Created by Paul Nettle on 11/23/16.
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

/// Represents a deck that was found within an image.
///
/// Contains a DeckLocation as well as CodeDefinition information and the error metric associated to the result.
public final class DeckMatchResult
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The DeckLocation (group of MarkLocations found in the image) for this MatchResult
	let deckLocation: DeckLocation

	/// The error metric associated to this DeckMatchResult
	let error: Real

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initializes a DeckMatchResult from its key components
	init(deckLocation: DeckLocation, error: Real)
	{
		self.deckLocation = deckLocation
		self.error = error
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Debug
	// -----------------------------------------------------------------------------------------------------------------------------

	func debugLogMatchInfo(codeDefinition: CodeDefinition)
	{
		gLogger.search("Deck matched using '\(codeDefinition.format.name)' with error: \(error) at \(String(describing: deckLocation.sampleLine))")
		gLogger.search("\(String.kNewLine)\(String(describing: deckLocation))")
	}

	func debugDrawOverlay(image: DebugBuffer?, codeDefinition: CodeDefinition)
	{
		// Draw the definition used to find this match
		codeDefinition.debugDrawOverlay(image: image, deckReference: deckLocation)
	}
}
