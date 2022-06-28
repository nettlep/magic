//
//  Decoder.swift
//  Seer
//
//  Created by Paul Nettle on 11/28/16.
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

/// The barcode scanner and decoder
///
/// Reads the barcodes printed on the marked deck, interpreting those barcodes into an ordered set of cards.
public final class Decoder
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	// This is our working deck - we have just one in order to reduce reallocation overhead
	private static var workDeck: Deck?

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Decodes a deck (ordered list of cards) from a given set of MarkLines and returns the DecodeResult.
	///
	/// Priority is given to accuracy, with all other considerations focused on being as efficient as possible. Given that, extra
	/// steps are taken during the decode process, such as analyzing the samples of the MarkLines to determine if their sharpness
	/// and if they are fit (or unfit) for decoding.
	///
	/// Efficiency of the decode process is attained by boiling it down to simple bit masking. This is made possible by the use of
	/// BitPatterns, which define the bits that match a maximal and unique set of bit combinations that span a set of rows,
	/// covering the jog range (see BitPattern for further details.) In addition, the MarkLines are also converted to a set of
	/// combined words covering the full jog range (see MarkLines.generateWordRows for details.)
	///
	/// Given a set of words that represent the masks and a set of words that represent rows of MarkLines, we simply need to
	/// perform the masking and combine the masks to form the final Card Code. This is a bit of tricky bit masking because
	/// (assuming a jog range of [-2,+2]) each word in the BitPattern and MarkLines represents five 12-bit values concatenated into
	/// a single 60-bit word. These 12 values must be shifted and merged into a single 12-bit value.
	///
	/// The results of this are stored in a Deck in the form of a series of ScannedRows of ScannedCards.
	///
	/// Ths Deck is then resolved in order to provide a final DecodeResult.
	///
	/// Possible DecodeResults are:
	///
	///		* NotSharp       - The image samples that form the MarkLines were determined to be too blurry
	///		* GeneralFailure - The MarkLines failed to convert to rows of words
	///		* TooFewCards    - The resolved deck fell below the minimum threshold (see Deck.kMinCards)
	///		* Decoded        - The deck was decoded with confidence
	///
	/// It should be noted that even a confident decode can be wrong. There is no way to guarantee a perfectly accurate decode,
	/// even manually by a human with high intelligence. Cards may be hidden or unreadable in the image. But most of these issues
	/// should be resolved via the use of a histogram of recent results to eliminate likely incorrect scans/decodes. For more
	/// information on this, see ScanManager.validateDecodedCards().
	class func decode(debugBuffer: DebugBuffer?, markLines: MarkLines, deckFormat: DeckFormat) -> DecodeResult
	{
		// We need to do this in order to ensure that the DeckFormat has everything it needs for decoding, such as error
		// correction maps, etc.
		if !deckFormat.prepareForDecode()
		{
			return .GeneralFailure(reason: "Unable to prepare DeckFormat")
		}

		// =-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-
		// Scan the deck top-down, building up an array of ScannedCards
		// =-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-

		// If we don't meet a minimum sharpness, don't bother trying to decode
		if Config.decodeEnableSharpnessDetection
		{
			ScanManager.decodeSharpnessFactor = markLines.calcMinimumSharpness()
			if ScanManager.decodeSharpnessFactor < Config.decodeMinimumSharpnessUnitScalarThreshold
			{
				return .NotSharp
			}
		}

		// Since we cache the work deck, if the deck format changes, we need to re-create our work deck
		if workDeck != nil && deckFormat.name != workDeck!.format.name
		{
			workDeck = nil
		}

		// Allocate a new work deck?
		if workDeck == nil
		{
			workDeck = Deck(format: deckFormat)
		}

		if let deck = workDeck, let words = markLines.generateBitWords(maxCardCount: deckFormat.maxCardCount)
		{
			deck.startResolveSession()

			// This will be handy for quick translation to indices
			let codeToIndexMap = deckFormat.mapCodeToErrorCorrectedIndex
			let indexToCodeMap = deckFormat.mapIndexToCode

			var lastCardIndex = 0
			var lastCardCount = 0
			var lastCardErrorCorrectedCount = 0

			// Scan through the bit rows
			for wordIndex in 0..<words.count
			{
				let cardCode = words[wordIndex]
				let cardIndex = codeToIndexMap[Int(cardCode)]

				// Add the new scanned card
				if cardIndex == HammingDistance.CardState.Unassigned.rawValue { continue }

				// Was this card error-corrected?
				let errorCorrected = indexToCodeMap[cardIndex] == Int(cardCode) ? 0 : 1

				if lastCardCount == 0
				{
					lastCardIndex = cardIndex
					lastCardCount = 1
					lastCardErrorCorrectedCount = errorCorrected
				}
				else if lastCardIndex == cardIndex
				{
					lastCardCount += 1
					lastCardErrorCorrectedCount += errorCorrected
				}
				else
				{
					let robustScore = lastCardCount > lastCardErrorCorrectedCount ? 1:0
					deck.addCard(deckFormat: deckFormat, cardIndex: UInt8(lastCardIndex), count: lastCardCount, robustness: UInt8(robustScore), rowIndex: wordIndex)

					lastCardIndex = cardIndex
					lastCardCount = 1
					lastCardErrorCorrectedCount = errorCorrected
				}
			}

			if lastCardCount != 0
			{
				let robustScore = lastCardCount > lastCardErrorCorrectedCount ? 1:0
				deck.addCard(deckFormat: deckFormat, cardIndex: UInt8(lastCardIndex), count: lastCardCount, robustness: UInt8(robustScore), rowIndex: words.count - 1)
			}

			deck.resolve(debugBitWords: words, deckFormat: deckFormat, bits: markLines.count)

			if deck.count < deck.format.minCardCount
			{
				return .TooFewCards(deck: Deck(deckForResults: deck))
			}

			return .Decoded(deck: Deck(deckForResults: deck))
		}

		return .GeneralFailure(reason: "There is no workDeck object")
	}
}
