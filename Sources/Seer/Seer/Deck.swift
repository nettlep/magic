//
//  Deck.swift
//  Seer
//
//  Created by Paul Nettle on 12/22/16.
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

/// Represents a deck of cards, as scanned from a printed code
public final class Deck
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The maximum sample height of a deck
	///
	/// Some operations need to know the maximum number of samples tall that a deck can be. The theoretical maximum would be the
	/// maximum dimension of any input image. However, as the deck would still need to fit on the screen (width-wise) and as the
	/// deck's width is greater than it's height, the theoretical maximum isn't possible. That's fine - we'll use a reasonably
	/// large number here that is certain to allow decks in a 4K image.
	public static let kMaxSampleHeight: Int = 4096

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Convenience property to access the DeckFormat from within the CodeDefinition
	public let format: DeckFormat

	/// ScannedCards in matrix form where each [row,col] indexing represents [scanned_row, occurrence_per_card_index]
	///
	/// This is used as intermediate storage during the resolve process
	private(set) static var cardMatrixByIndex = StaticMatrix<ScannedCard>(rowCapacity: 1, colCapacity: 1)

	/// ScannedCards in matrix form where each [row,col] indexing represents [card_index, occurrence_per_scanned_row]
	///
	/// This is used as intermediate storage during the resolve process
	internal static var cardMatrixByRow = StaticMatrix<ScannedCard>(rowCapacity: 1, colCapacity: 1)

	/// The list of card indices stored in this deck
	public private(set) var resolvedIndices = [UInt8]()

	/// The list of card robustness values stored in this deck (in the same order as `resolvedIndices`)
	public private(set) var resolvedRobustness = [UInt8]()

	/// Returns the number of indices in the deck
	var count: Int { return resolvedIndices.count }

	/// Returns true if the deck contains no card indices (either it was never resolved, or it resolved to no cards)
	var isEmpty: Bool { return resolvedIndices.isEmpty }

	/// Index into the list of card indices
	///
	/// Note that the indices will not exist until the deck is resolved (see resolve())
	subscript(index: Int) -> UInt8 { return resolvedIndices[index] }

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a Deck with a given `DeckFormat`
	init(format: DeckFormat)
	{
		self.format = format
	}

	/// Initializes a Deck (for use with results) from another Deck
	///
	/// This is a specialization for optimization purposes. The deck used during a resolve process will include the scanned cards
	/// array (of arrays) which is costly to manage the retention of. However, that information isn't needed for the results, so we
	/// initialize the deck without copying at deep data from the source deck.
	init(deckForResults deck: Deck)
	{
		self.format = deck.format
		self.resolvedIndices = deck.resolvedIndices
		self.resolvedRobustness = deck.resolvedRobustness
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Deck resolution
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Ensure the Deck has appropriate storage available for adding cards prior to decoding
	///
	/// This method must be called at the start of a resolve session, prior to calling `addCard()`
	@inline(__always) func startResolveSession()
	{
		// The capacity here is arbitrary and will get resized as needed
		Deck.cardMatrixByIndex.ensureReservation(rowCapacity: format.maxCardCountWithReversed, colCapacity: 1024)
		Deck.cardMatrixByRow.ensureReservation(rowCapacity: 1024, colCapacity: format.maxCardCountWithReversed)
	}

	/// Add a card to the deck, for use with deck resolution
	///
	/// In order to resolve a deck, cards must first be added to the deck. There may be multiple occurrences of a card and they may
	/// be added in any order. The job of the resolution process is to resolve the unordered super-collection of cards into a
	/// cohesive deck (or an appropriate failure result.) For more information on the resolution process, see `resolve()`.
	///
	/// Be sure to call `startResolveSession` before calling this method
	@inline(__always) func addCard(deckFormat: DeckFormat, cardIndex: UInt8, count: Int, robustness: UInt8, rowIndex: Int)
	{
		// For convenience: Integer version of our card index
		let iCardIndex = Int(cardIndex)

		// If it already exists for this row, just increment the card
		let end = Deck.cardMatrixByIndex.colCount(row: iCardIndex)
		for i in 0..<end
		{
			if Deck.cardMatrixByIndex[iCardIndex, i].rowIndex == rowIndex
			{
				Deck.cardMatrixByIndex[iCardIndex, i].increment(count: count, robustness: robustness)
				return
			}
		}

		// Create a new ScannedCard and add it to the list
		let newCard = ScannedCard(id: Deck.cardMatrixByIndex.count, cardIndex: cardIndex, rowIndex: rowIndex, count: count, robustness: robustness)
		Deck.cardMatrixByIndex.add(toRow: iCardIndex, value: newCard)
	}

	/// Resolve the raw set of ScannedRows (of ScannedCards) into a single set of card indices, returning that set of indices for a
	/// solution.
	///
	/// The resolution process is the final and critical step in determining the existence and ordering of cards in a deck of cards
	/// found within an image.
	///
	/// Resolve sessions
	///
	///		A resolve session starts by calling the aptly named method, `startResolveSession`. This resets the internal memory used
	///		by the decoder and prepares it to start accepting cards.
	///
	///		The next step is to add the various cards found from raw scans. This is done by calling `addCard()` for each card found
	///		in the scanned image.
	///
	///		Finally, call this method to resolve the unordered super-set of cards into a single, cohesive deck (or an appropriate
	///		failure result.)
	///
	/// Implementation details
	///
	///     The cards in this deck are assumed to be grouped by consecutive counts (see `Decoder.decode()`)
	///
	///		Each ScannedRow can contain a number of ScannedCards, often of multiple face values. Some of those cards may be false
	///		positives and cases of multiple cards overlapping the same rows is commonplace. This poses a challenge to resolving the
	///		true order of the deck.
	///
	///		Fortunately, there is a lot of information available. Each rows notes the set of cards scanned from that row along with
	///		the frequency for that card.
	///
	///		Using this information, the deck is resolved through the use of a set of rules. Each rule is crafted to make decisions
	///		that with a configurable level of confidence. This confidence comes from using the available data to find consensus
	///		among the data itself.
	///
	///		The result will be stored in the Deck's `resolvedIndices` property.
	///
	/// Challenge confidence and ties
	///
	///		The challenges applied within rules is the key aspect of the resolution process. A confident challenge (say, a winning
	///		card is chosen only if it wins by a factor of 2) will be likely to produce a higher percentage of correct results while
	///		also providing more inconclusive results when a winner cannot be clearly chosen. Conversely, a less confident challenge
	///		will produce more winners, even if those winners are sometimes incorrect. More winners (correct or otherwise) means
	///		more results, at least some of which are likely to be correct, allowing for more reports back to the user.
	///
	///		Theoretically, it should be better to go with the less confident challenge as this would increase the total number of
	///		results for consideration. If there is not a tie, then the statistically likelihood of a correct result would be above
	///		50%. The down-side to this is that the overall accuracy percentage is likely to drop, placing a higher reliance on the
	///		statistical history to cull those results that are invalid.
	///
	///		By extension, a winner chosen at random from a tie would have a similar effect, with the probability of the result
	///		being 50%.
	func resolve(debugBitWords: UnsafeMutableArray<MarkLines.BitWord>?, deckFormat: DeckFormat, bits: Int)
	{
		let _track_ = PerfTimer.ScopedTrack(name: "Resolve"); _track_.use()

		// Merge the reversed cards
		if deckFormat.reversible
		{
			let maxCardCount = deckFormat.maxCardCount
			for forwardRow in 0..<maxCardCount
			{
				var forwardTotal = 0
				for col in 0..<Deck.cardMatrixByIndex.colCount(row: forwardRow)
				{
					forwardTotal += Deck.cardMatrixByIndex[forwardRow, col].count
				}

				let reversedRow = forwardRow + maxCardCount
				var reversedTotal = 0
				for col in 0..<Deck.cardMatrixByIndex.colCount(row: reversedRow)
				{
					reversedTotal += Deck.cardMatrixByIndex[reversedRow, col].count
				}

				if forwardTotal >= reversedTotal
				{
					Deck.cardMatrixByIndex.remove(row: reversedRow)
				}
				else
				{
					Deck.cardMatrixByIndex.remove(row: forwardRow)
				}
			}
		}

		var resolveLog = [String]()
		if gLogger.isSet(LogLevel.Resolve)
		{
			if let words = debugBitWords
			{
				var bitCols = [String]()
				bitCols.reserveCapacity(words.count)
				for i in 0..<words.count { bitCols.append("\(i.toString(3)):") }
				resolveLog = bitCols.columnize(prefix: "  ")

				bitCols.removeAll(keepingCapacity: true)
				for i in 0..<words.count { bitCols.append(Int(words[i]).binaryStringAscii(bits, reversed: true)) }
				resolveLog = resolveLog.addColumn(with: bitCols, header: "MARK BITS")
			}

			resolveLog = debugAddMatrixColumn(deckFormat: deckFormat, header: "ORIGINAL", matrix: Deck.cardMatrixByIndex, rows: resolveLog)
		}

		genocide()
		if gLogger.isSet(LogLevel.Resolve)
		{
			resolveLog = debugAddMatrixColumn(deckFormat: deckFormat, header: "AFTER GENOCIDE", matrix: Deck.cardMatrixByIndex, rows: resolveLog)
		}

		revenge()
		if gLogger.isSet(LogLevel.Resolve)
		{
			resolveLog = debugAddMatrixColumn(deckFormat: deckFormat, header: "AFTER REVENGE", matrix: Deck.cardMatrixByRow, rows: resolveLog)
			gLogger.array(level: .Resolve, array: resolveLog, header: "Resolve progress (\(resolveLog.count) rows):")
		}

		// Clean out our array of resolved indices
		resolvedIndices.removeAll(keepingCapacity: true)
		resolvedRobustness.removeAll(keepingCapacity: true)

		// Grow it if we need to
		if resolvedIndices.capacity < format.maxCardCountWithReversed
		{
			resolvedIndices.reserveCapacity(format.maxCardCountWithReversed)
			resolvedRobustness.reserveCapacity(format.maxCardCountWithReversed)
		}

		// Sort and build our array of ordered cards
		for row in 0..<Deck.cardMatrixByRow.rowCount()
		{
			let cols = Deck.cardMatrixByRow.colCount(row: row)
			for col in 0..<cols
			{
				resolvedIndices.append(Deck.cardMatrixByRow[row, col].cardIndex)
				resolvedRobustness.append(Deck.cardMatrixByRow[row, col].robustness)
			}
		}

		// Add this to our history
		History.instance.addEntry(indices: resolvedIndices, deckFormat: format)

		if gLogger.isSet(LogLevel.Result)
		{
			gLogger.result("Result: \(faceCodes(faceCodes: format.getFaceCodes(indices: resolvedIndices, reversed: true)))")
		}
	}

	/// Performs final analysis on the deck and returns an `AnalysisResult`
	///
	/// Implementation notes:
	///
	/// The analysis is largely dependent upon history and hence, `History.analyze` is the primary analysis tool. To that end, the
	/// history may return a new set of indices. In that case, the `resolvedIndices` stored in this deck may be replaced by those
	/// from the history.
	public func analyze(deckSearchResult: SearchResult, decodeResult: DecodeResult) -> AnalysisResult
	{
		// Here we perform the history analysis
		guard let indices = History.instance.analyze(deck: self) else
		{
			return .Inconclusive(deckSearchResult: deckSearchResult, decodeResult: decodeResult, deck: self)
		}

		// Update our resolved indices
		assert(indices.max()! <= UInt8(format.maxCardCountWithReversed))
		resolvedIndices = indices

		if History.instance.calcTotalHistorySize() < Config.analysisMinHistoryEntries
		{
			return .InsufficientHistory(deckSearchResult: deckSearchResult, decodeResult: decodeResult, deck: self)
		}

		// Our confidence factor
		//
		// Note that if the maxResultCountNotOurs is zero, we can't divide, so instead we set it to 1, not only to enable division
		// but this also uses our result count as the factor, which is a reasonable thing to do.
		let confidenceFactor = History.instance.calcConfidence()

		if confidenceFactor < Config.analysisMinimumConfidenceFactorThreshold
		{
			return .InsufficientConfidence(deckSearchResult: deckSearchResult, decodeResult: decodeResult, confidence: confidenceFactor, deck: self)
		}
		else if confidenceFactor < Config.analysisHighConfidenceFactorThreshold
		{
			return .SuccessLowConfidence(deckSearchResult: deckSearchResult, decodeResult: decodeResult, confidence: confidenceFactor, deck: self)
		}
		else
		{
			return .SuccessHighConfidence(deckSearchResult: deckSearchResult, decodeResult: decodeResult, confidence: confidenceFactor, deck: self)
		}
	}

	/// The Genocide Rule
	///
	/// Input/Output:
	///
	///		A StaticMatrix of ScannedCard objects (stored in `cardMatrixByIndex`) in which the rows within the matrix refer to
	///		card indices.
	///
	/// Discussion:
	///
	///		Real cards should be very strong (mostly large consecutive groups of same cards.) Any stragglers are most likely to
	///     be weak and lonely cards surrounded by large groups of same cards. Even more importantly, their distant sibling is also
	///     very likely to be a more substantial consecitive group of similar cards.
	///
	///		The Genocide rule is intended to seek out any occurrences of errant cards (i.e., more than one instance of a card in
	///		the entire set.) The two cards are challenged and if a winner is chosen, the losing card is simply removed from the
	///		deck.
	private func genocide()
	{
		// Scan the map for disjoint cards
		let end = Deck.cardMatrixByIndex.rowCount()
		for cardIndex in 0..<end
		{
			// We only care about rows that have more than 1 card
			let instanceCount = Deck.cardMatrixByIndex.colCount(row: cardIndex)
			if instanceCount <= 1 { continue }

			var strongestCard = Deck.cardMatrixByIndex[cardIndex, 0]
			for cardInstance in 1..<instanceCount
			{
				let thisCard = Deck.cardMatrixByIndex[cardIndex, cardInstance]
				assert(thisCard.rowIndex != strongestCard.rowIndex)

				// Skip empty cards
				if thisCard.count == 0 { continue }

				// Challenge to find the strongest
				if strongestCard.count == 0 || strongestCard.challengeGenocide(challengee: thisCard) < 0
				{
					strongestCard = thisCard
				}
			}

			if strongestCard.count == 0 { continue }

			// One more time through the list, this time to wipe out the losing cards
			for cardInstance in 0..<instanceCount
			{
				let thisCard = Deck.cardMatrixByIndex[cardIndex, cardInstance]

				// Skip empty cards
				if thisCard.count == 0 { continue }

				// Skip the strongest card
				if thisCard.rowIndex == strongestCard.rowIndex { continue }

				// Challenge one more time to see if we have a tie
				let challenge = strongestCard.challengeGenocide(challengee: thisCard)
				if challenge < 2
				{
					// The challenge failed, do nothing and let `revenge()` deal with it
					continue
				}

				// Remove the weak card from its row
				Deck.cardMatrixByIndex[cardIndex, cardInstance].clear()
			}
		}
	}

	/// The Revenge Rule
	///
	/// Input:
	///
	///		A StaticMatrix of ScannedCard objects (stored in `cardMatrixByIndex`) in which the rows within the matrix refer to
	///		card indices.
	///
	/// Output:
	///
	///		A StaticMatrix of ScannedCard objects (stored in `cardMatrixByRow`) in which the rows within the matrix refer to the
	///		scanned rows from the image, providing an in-order list of cards as they appear in the deck.
	///
	/// Discussion:
	///
	///		Following the Genocide rule, the deck should be mostly resolved, if not completely resolved. In the cases where the
	///		deck is not completely resolved, the deck will contain duplicate occurrences of at least one card (but possibly many.)
	///		In some cases, these duplicates can be resolved if the duplicates are neighbors of each other.
	///
	///		The Revenge rule is intended to locate all duplicates and remove the neighbors. It is possible for duplicates to remain
	///     in the set following a revenge - it is expected that the history merge will resolve these conflicts.
	///
	///		During this process, the deck's data is culled (removing consumed cards) and moved from `cardMatrixByIndex` to
	///		`cardMatrixByRow`, effectively pivoting that table. This is an important step to simplify remaining processing, which
	///		works on the deck in the order it appears in the scanned deck.
	private func revenge()
	{
		// Before we pivot the matrix on its side, ensure that our output matrix has enough capacity (inverse of the original)
		Deck.cardMatrixByRow.ensureReservation(rowCapacity: Deck.cardMatrixByIndex.colCapacity, colCapacity: Deck.cardMatrixByIndex.rowCapacity)

		// Pivot the matrix onto its side, ignoring empty (consumed) cards
		//
		// During this process, we'll keep track of the number of duplicate cards we find
		var duplicateCards = 0
		let rows = Deck.cardMatrixByIndex.rowCount()
		for row in 0..<rows
		{
			let cols = Deck.cardMatrixByIndex.colCount(row: row)
			var cardCount = 0
			for col in 0..<cols
			{
				// We only add cards that have a count
				let card = Deck.cardMatrixByIndex[row, col]
				if card.count > 0
				{
					Deck.cardMatrixByRow.add(toRow: card.rowIndex, value: card)
					cardCount += 1
				}
			}

			// Track total duplicates
			if cardCount > 1
			{
				duplicateCards += cardCount - 1
			}
		}

		// Now that the matrix is complete, revisit it in row-order to remove any consecutive duplicates
		if duplicateCards > 0
		{
			var lastCardIndex = -1
			let rows = Deck.cardMatrixByRow.rowCount()
			for row in 0..<rows
			{
				var cols = Deck.cardMatrixByRow.colCount(row: row)
				var col = 0
				while col < cols
				{
					let card = Deck.cardMatrixByRow[row, col]

					// Check if this card is the same card as the previous
					if Int(card.cardIndex) != lastCardIndex
					{
						// Nope, different card. Track the new index and move to the next column
						lastCardIndex = Int(card.cardIndex)
						col += 1
					}
					else
					{
						// Same card, remove this occurrence
						Deck.cardMatrixByRow.remove(row: row, col: col)
						duplicateCards -= 1
						cols -= 1
					}
				}
			}
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Validation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Validates the deck against our known test deck order, returning the boolean result
	///
	/// The parameters missingCards and unorderedCards will receive the face code strings for those cards that were missing from
	/// the scan, or appeared out of order (respectively.)
	///
	/// In addition, the scannedComparison and knownComparison are two arrays of Strings that contain a useful visual
	/// representation of the results, such that it is clear which cards were skipped (and where), which cards were missing. These
	/// arrays are formatted to be minimalistic in size, but fully informative. Cards that were found out of order are represented
	/// clearly, regardless of where the actual card was found.
	///
	/// * Missing cards appear as dashes ("--") in the space where they should have appeared in the scanned set
	/// * Cards that are found out of order will appear as a gap in the known set
	/// * Known cards beyond the end of the scanned set will be highlighted with asterisks ("**")
	/// * The routine is smart enough to fix up out-of-order cards by looking ahead and behind in order to determine the best
	///   visual representation
	public func validateAgainstKnownDeck(missingCards: inout [String], unorderedCards: inout [String], scannedComparison: inout [String], knownComparison: inout [String]) -> Bool
	{
		// Cleanup our input arrays
		missingCards.removeAll(keepingCapacity: true)
		unorderedCards.removeAll(keepingCapacity: true)
		scannedComparison.removeAll(keepingCapacity: true)
		knownComparison.removeAll(keepingCapacity: true)

		if isEmpty
		{
			return false
		}

		// Get the face codes for our scanned card indices
		let scannedFaceCodes = format.getFaceCodes(indices: resolvedIndices)

		// Get the test deck order from the code
		let knownTestDeckFaceCodes = format.faceCodesTestDeckOrder

		var knownIndex = 0
		var scannedIndex = 0
		while true
		{
			let scannedEnd = scannedIndex >= scannedFaceCodes.count
			let knownEnd = knownIndex >= knownTestDeckFaceCodes.count

			// Done?
			if scannedEnd && knownEnd { break }

			// Things we keep track of
			var missing = false
			var outOfOrder = false
			var skipScanned = false
			var pastKnownEnd = false

			// Get the scanned code and/or the known code
			let scannedCode: String? = scannedEnd ? nil : scannedFaceCodes[scannedIndex]
			let knownCode: String? = knownEnd ? nil : knownTestDeckFaceCodes[knownIndex]

			// If ran out of known codes, this scanned code is out of order
			if knownEnd
			{
				outOfOrder = true
				pastKnownEnd = true
			}
			// If we ran out of scanned codes, it may be missing or out of order
			else if scannedEnd
			{
				// Find the known code in the scanned list
				if !scannedFaceCodes.contains(knownCode!)
				{
					missing = true
				}
				// Not missing, but we already passed it out of order
				else
				{
					skipScanned = true
				}
			}
			// If it wasn't a match, determine what type of mismatch
			else if knownCode! != scannedCode!
			{
				let actualScannedIndex = scannedFaceCodes.firstIndex(of: knownCode!)

				// Did we find it at all?
				if let actualScannedIndex = actualScannedIndex
				{
					// If it's behind us, we already passed it (it appeared out of order)
					if actualScannedIndex < scannedIndex
					{
						skipScanned = true
					}
					// If it's in front of us, one of two scanned codes is out of order
					else
					{
						// The distance to where this code was eventually scanned
						let actualOffset = actualScannedIndex - scannedIndex

						// The distance to where the current scanned code is, and where it should be
						let knownOffset = knownTestDeckFaceCodes.firstIndex(of: scannedCode!)! - scannedIndex

						// If the known offset is behind us, we already skipped it in order to mark it out of order here
						if knownOffset < 0
						{
							outOfOrder = true
						}
						// The known offset is closer, which means the known code will be fond later (out of order)
						else if knownOffset < actualOffset
						{
							skipScanned = true
						}
						// The actual offset is closer, which means the current scanned code is out of order
						else
						{
							outOfOrder = true
						}
					}
				}
				// We never found the code, mark it as missing
				else
				{
					missing = true
				}
			}

			if missing
			{
				scannedComparison.append("--")
				knownComparison.append(knownCode!)
				missingCards.append(knownCode!)
				knownIndex += 1
			}
			else if outOfOrder
			{
				scannedComparison.append(scannedCode!)
				knownComparison.append(pastKnownEnd ? "**" : "  ")
				unorderedCards.append(scannedCode!)
				scannedIndex += 1
			}
			else if skipScanned
			{
				scannedComparison.append("  ")
				knownComparison.append(knownCode!)
				knownIndex += 1
			}
			else // This was a match
			{
				scannedComparison.append(scannedCode!)
				knownComparison.append(knownCode!)
				knownIndex += 1
				scannedIndex += 1
			}
		}

		// An empty set of unordered and missing cards means a successful match
		return unorderedCards.count == 0 && missingCards.count == 0
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the full set of face codes (from the set of resolved indices) as a string, separated by spaces
	public func getFaceCodesString() -> String
	{
		return getFaceCodes(indices: resolvedIndices).joined(separator: " ")
	}

	/// Returns the array of card indices to an array of Face Codes
	public func getFaceCodes(indices: [UInt8]) -> [String]
	{
		return format.getFaceCodes(indices: indices)
	}

	/// Returns the deck's card face codes
	public func faceCodes(faceCodes: [String]) -> String
	{
		return faceCodes.joined(separator: " ")
	}

	/// Returns an array of indices that are missing from the deck
	public func getMissingIndices() -> [UInt8]
	{
		var missingIndices = [UInt8]()
		for i in 0..<format.maxCardCount
		{
			if !resolvedIndices.contains(UInt8(i)) && !resolvedIndices.contains(UInt8(i + format.maxCardCount))
			{
				missingIndices.append(UInt8(i))
			}
		}

		return missingIndices
	}

	/// Returns the full set of face codes (from the set of missing indices) as a string, separated by spaces
	public func getMissingFaceCodesString() -> String
	{
		return getMissingFaceCodes(indices: resolvedIndices).joined(separator: " ")
	}

	/// Returns the array of missing card indices to an array of Face Codes
	public func getMissingFaceCodes(indices: [UInt8]) -> [String]
	{
		return format.getFaceCodes(indices: getMissingIndices())
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Debug
	// -----------------------------------------------------------------------------------------------------------------------------

	private func debugAddMatrixColumn(deckFormat: DeckFormat, header: String, matrix: StaticMatrix<ScannedCard>, rows: [String]) -> [String]
	{
		var strings = [String]()
		strings.reserveCapacity(matrix.rowCount())
		for row in 0..<matrix.rowCount()
		{
			for col in 0..<matrix.colCount(row: row)
			{
				let card = matrix[row, col]
				if card.count > 0
				{
					while strings.count <= card.rowIndex
					{
						strings.append("")
					}
					strings[card.rowIndex] += card.description(deckFormat: deckFormat) + " "
				}
			}
		}
		return rows.addColumn(with: strings, prefix: "||", header: header)
	}

	//
	// Debug
	//

	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		return "\(resolvedIndices) resolved cards)"
	}
}
