//
//  ScannedCard.swift
//  Seer
//
//  Created by Paul Nettle on 1/28/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

// ---------------------------------------------------------------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------------------------------------------------------------

/// Represents a single card that was scanned during the decoding process.
///
/// ScannedCards are intended for use in a structure consisting of a series of rows of data in which each row may contain 0...n
/// ScannedCards. ScannedCards are not only meant to be collected during the decoding process, but they are also designed to be
/// specifically useful during the deck resolution process, where the results from aggressive decoding are resolved to a single
/// cohesive deck.
///
/// The resolution process involves solving disputes (with the highest possible confidence) between multiple cards residing on a
/// single row. Much of this is made possible by the data stored in (and manipulated by) the ScannedCard.
struct ScannedCard
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The index of the card that was decoded
	public let cardIndex: UInt8

	/// The number of occurrences of this card
	private(set) var count: Int

	/// The robustness score for this card
	private(set) var robustness: UInt8

	/// The row where this card resides
	public let rowIndex: Int

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a ScannedCard from the essentials
	init(id: Int, cardIndex: UInt8, rowIndex: Int, count: Int = 1, robustness: UInt8 = 0)
	{
		self.cardIndex = cardIndex
		self.count = count
		self.robustness = robustness
		self.rowIndex = rowIndex
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Card management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Resets the card to unused
	@inline(__always) mutating func clear()
	{
		count = 0
		robustness = 0
	}

	/// Increment the occurrence count for this card with the BitPattern that was used to find this card
	@inline(__always) mutating func increment(count: Int, robustness: UInt8)
	{
		self.count += count
		self.robustness = max(self.robustness, robustness)
	}

	/// Consumes `card` capturing its counters
	///
	/// In addition, `card` is left empty of its count
	@inline(__always) mutating func consume(card: inout ScannedCard)
	{
		count += card.count
		robustness += card.robustness

		card.count = 0
		card.robustness = 0
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Challenge cards for competing placement
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Challenges a card for the Genocide challenge
	///
	/// Note that this routine uses a multiple of 2 for the challenge. As this is technically a magic number, it seems to work well
	/// and is a standard multiplier in life in general. So we'll just say "it's gotta be twice the card the other one is" and
	/// leave it at that. :)
	///
	/// Returns:
	///
	///		+2 - The challenger (this card) is the clear winner
	///		-1 - The challenger (this card) is stronger, but does not win
	///		 0 - The two cards are equal in the eyes of the genocide challenge
	///		-1 - The challengee is stronger, but does not win
	///		-2 - The challengee is the clear winner
	@inline(__always) func challengeGenocide(challengee: ScannedCard) -> Int
	{
		if count > challengee.count
		{
			return count > (Config.resolveGenocideScaleFactor * challengee.count).floor() ? 2 : 1
		}
		if challengee.count > count
		{
			return challengee.count > (Config.resolveGenocideScaleFactor * count).floor() ? -2 : -1
		}
		return 0
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension ScannedCard: CustomStringConvertible, CustomDebugStringConvertible
{
	var debugDescription: String
	{
		// Don't call this directly, use `debugDescription(deckFormat:)`
		assert(false)
		return ""
	}

	var description: String
	{
		// Don't call this directly, use `description(deckFormat:)`
		assert(false)
		return ""
	}

	func debugDescription(deckFormat: DeckFormat) -> String
	{
		return description(deckFormat: deckFormat)
	}

	func description(deckFormat: DeckFormat) -> String
	{
		let faceCode = deckFormat.faceCodesNdo[Int(cardIndex)]
		return "[\(faceCode) \(count.toString(3))]"
	}

	func shortDescription(deckFormat: DeckFormat) -> String
	{
		let faceCode = deckFormat.faceCodesNdo[Int(cardIndex)]
		return "\(faceCode)[\(count.toString())]"
	}
}
