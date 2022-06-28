//
//  History.swift
//  Seer
//
//  Created by Paul Nettle on 2/25/17.
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

/// Performs statistical analysis on decoded deck results using recent-historic results.
///
/// The goal is to determine if a decoded deck result should be "reported" (to the user) or "suppressed".
///
/// "Reports"     Come in two flavors: high and low confidence. With each, their actual confidence factor is provided.
/// "Supressions" Results that lack sufficient history for analysis or have been determined to likely be incorrect (i.e., lacking
///               confidence.)
public final class History
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// A unique result (in the form of the set of indices) in the history
	///
	/// A single `Entry` may be present in the history multiple times. Rather than duplicating multiple entries in the history, an
	/// array of timestamps is included that allow us to calculate the age of each history entry (and prune older entries by simply
	/// removing the timestamp from the array.)
	private struct Entry
	{
		/// The set of indices that this history entry represents
		var indices: [UInt8]

		/// The timestamps for each time this entry was added to the history
		var timestamps: [Time]

		/// Initialize the entry from its base constituents
		init(indices: [UInt8], timestamps: [Time] = [Time]())
		{
			self.indices = indices
			self.timestamps = timestamps
		}

		/// The number of times this entry appears in the history
		///
		/// This is simply calculated by the number of timestamps in this entry
		var count: Int
		{
			return timestamps.count
		}

		/// Adds a timestamp to this entry (thus increasing `count` by 1)
		mutating func addTimestamp(_ timestamp: Time)
		{
			timestamps.append(timestamp)
		}

		/// Removes timestamps that are older than `maxHistoryAgeMS` (thus decreasing `count` by the number of entries that were
		/// removed)
		mutating func removeOldEntries(maxHistoryAgeMS: Int)
		{
			let oldestAllowedTimeMS = PausableTime.getTimeMS() - Time(Config.analysisMaxHistoryAgeMS)

			// Keep all elements not older than `oldestAllowedTimeMS`
			timestamps = timestamps.filter {$0 > oldestAllowedTimeMS}
		}
	}

	/// A unique link from one card to another
	///
	/// The analysis process merges the full history into a set of card-to-card links, which is then consolidated into an array
	/// of links representing the order of all cards.
	///
	/// A unique link may actually appear multiple times throughout the full history, so each `Link` includes a `count` to track
	/// the frequency (strength, weight) of this link.
	///
	/// A link is represented as a link from `source` to `target`. For example, if we are linking `2H` to `3H`, then `source` would
	/// be the index for `2H` and `target` would be the index for `3H`.
	private struct Link
	{
		/// The source card index
		let source: UInt8

		/// The target card index
		let target: UInt8

		/// The number of times this link appears in the full history
		var count: Int
	}

	/// A link matrix, containing all links across the entire history
	///
	/// The `row` represents the `source` index and each column representing a `target` that `source` links to.
	private typealias LinkMatrix = StaticMatrix<Link>

	/// A linear set of links, consolidated from a `LinkMatrix`
	///
	/// By examining the `source` for each entry, one will find an ordered list of indices
	///
	/// Note that a `ConsolidatedLinks` array may contain head or tail markers.
	private typealias ConsolidatedLinks = UnsafeMutableArray<Link>

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Singleton interface
	private static var singletonInstance: History?
	public static var instance: History
	{
		get
		{
			if singletonInstance == nil
			{
				singletonInstance = History()
			}

			return singletonInstance!
		}
		set
		{
			assert(singletonInstance != nil)
		}
	}

	/// Our local history entries
	///
	/// This is our history
	private var entries = [Entry]()

	/// The deck format for the entries in the history
	///
	/// This is important because histories store indices, which are `DeckFormat`-dependent.
	///
	/// If the deck format ever changes, the history must be reset (see `reset()`)
	private var deckFormat: DeckFormat?

	/// A special index used to delineate a head marker for linking cards
	///
	/// For simplicity of logic, every index must be linked to and must also link to the next index. We use head and tail markers
	/// to accomplish this. In effect, a list starts with a head marker, that links to the first card, through all cards in the
	/// list and ends with a tail marker.
	///
	/// Head and tail markers are calculated to immediately follow the largest index in the deck.
	private var cardIndexHead: UInt8 = 0

	/// A special index used to delineate a tail marker for linking cards
	///
	/// For simplicity of logic, every index must be linked to and must also link to the next index. We use head and tail markers
	/// to accomplish this. In effect, a list starts with a head marker, that links to the first card, through all cards in the
	/// list and ends with a tail marker.
	///
	/// Head and tail markers are calculated to immediately follow the largest index in the deck.
	private var cardIndexTail: UInt8 = 0

	/// A link from card-to-card, which allows us to track which cards follow which
	///
	/// This is initially declared as a 1x1 array and is reallocated as needed
	private var linkMatrix = LinkMatrix(rowCapacity: 1, colCapacity: 1)

	/// A linear set of links, typically consolidated from a `LinkMatrix`
	private var consolidatedLinks = ConsolidatedLinks()

	/// An internal-use array used to quickly find the full set of missing indices
	private var missingIndices = UnsafeMutableArray<Bool>()

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// We use a private initializer to enforce our singleton interface
	private init() {}

	/// Adds a fully decoded entry to the history for the given `deckFormat`
	///
	/// Important: The entry should be the raw decoded result, as this is then used later for analyis by merging the history
	/// entries. Using the raw entries provides a more accurate analysis.
	///
	/// Implementation notes:
	///
	/// If the provided `deckFormat` does not match the stored `deckFormat` for the history, then `History.deckFormat` is updated
	/// and the full history is reset (see `reset()`.)
	public func addEntry(indices: [UInt8], deckFormat: DeckFormat)
	{
		// If our format changed, reset history completely
		if self.deckFormat == nil || self.deckFormat! != deckFormat
		{
			self.deckFormat = deckFormat
			reset()
		}
		else
		{
			// Clean out the old history entries
			prune()
		}

		// Add the new entry to our history
		var historyIndex = findHistoryIndex(of: indices)
		if historyIndex == nil
		{
			entries.append(Entry(indices: indices))
			historyIndex = entries.count - 1
		}

		entries[historyIndex!].addTimestamp(PausableTime.getTimeMS())
	}

	/// Determine the probability of a scanned set of card indices is likely to be valid and return a confidence factor.
	///
	/// Validation is performed using a statistical analysis of incoming results against the recent history of results. This
	/// approach follows the premise that the scanning and decoding process is designed to return correct results and that those
	/// results will gravitate towards correctness.
	///
	/// It is surmised that any deviation from a correct result will be generally minor and caused by the lossy and imprecise
	/// nature of the input. It is further surmised that as errors introduced by by lossy and imprecise input will introduce
	/// probabilistically random errors.
	///
	/// Therefore, it follows that a sample of results over a period of time should contain a random distribution of errors with
	/// a single clear outlier for the correct answer.
	///
	/// It is important to note that not all errors are caused by lossy and imprecise input. Some examples of errors introduced
	/// by input that can generate consistent errors:
	///
	///    * Poorly printed marks on a marked deck
	///    * An environmental condition (a deck sitting on a shag carpet obscuring the bottom group of cards)
	///
	/// The confidence factor:
	///
	/// This factor represents the relative ratio between the number of times this particular deck has been scanned with the number
	/// of times that the largest of any other result was scanned.
	///
	/// If the card indices being validated were the most popular, then the confidence factor will be a positive value >= 1.0,
	/// which represents how much more popular this result was, compared to the second-most-popular result. If, for example, this
	/// result was scanned 10 times and the next-most-popular result was only scanned 3 times, then the confidence factor will
	/// be 3.333 (this result was 3.333 times more popular.)
	///
	/// If the card indices being validated were not the most popular, then the confidence factor will be a value in the range
	/// [0.0 < factor < 1.0].
	///
	/// If we do not have enough history, then the confidence factor returned will be 0.0
	///
	/// Finally, this method can return nil in cases of inconclusive decodes. This is done in order to allow inconclusive results
	/// to contribute to the history, but we do not want to return any results (or track any stats.)
	public func analyze(deck: Deck) -> [UInt8]?
	{
		// Merge
		let mergeHistoryStart = PerfTimer.trackBegin()
		guard let mergedLinks = merge() else
		{
			PerfTimer.trackEnd(name: "Merge History", start: mergeHistoryStart)
			return nil
		}
		PerfTimer.trackEnd(name: "Merge History", start: mergeHistoryStart)

		// Ensure we start at the head, but do not end at the tail. This odd asymmetry is intentional and has to do with the logic
		// of the history merge process
		assert(mergedLinks[0].source == cardIndexHead)
		assert(mergedLinks[mergedLinks.count-1].source != cardIndexTail)
		if mergedLinks[0].source != cardIndexHead || mergedLinks[mergedLinks.count-1].source == cardIndexTail { return nil }

		// Build an array of indices for the deck
		var indices = [UInt8]()
		indices.reserveCapacity(mergedLinks.count)

		// Note we skip the first entry in order to skip the head
		for i in 1..<mergedLinks.count
		{
			indices.append(mergedLinks[i].source)
		}

		return indices
	}

	/// Returns the index within the history that matches the given set of indices, or `nil` if not found
	private func findHistoryIndex(of indices: [UInt8]) -> Int?
	{
		return findHistoryIndex(of: indices, from: entries)
	}

	/// Returns the index within a merged history that matches the given set of indices, or `nil` if not found
	private func findHistoryIndex(of indices: [UInt8], from entries: [Entry]) -> Int?
	{
		for i in 0..<entries.count
		{
			if entries[i].indices == indices { return i }
		}

		return nil
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	//  _   _ _     _                      __  __
	// | | | (_)___| |_ ___  _ __ _   _   |  \/  | ___ _ __ __ _  ___
	// | |_| | / __| __/ _ \| '__| | | |  | |\/| |/ _ \ '__/ _` |/ _ \
	// |  _  | \__ \ || (_) | |  | |_| |  | |  | |  __/ | | (_| |  __/
	// |_| |_|_|___/\__\___/|_|   \__, |  |_|  |_|\___|_|  \__, |\___|
	//                            |___/                    |___/
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Merge all history entries into a single set of links that defines the final order of indices
	///
	/// This is a rather involved process that starts by building a link matrix of every link (i.e., a pair of cards seen next to
	/// each other in the history.)
	///
	/// Once this full matrix of links is created, all of the links are analyzed and consolidated into a single list of links that
	/// defines the (nearly) final set of indices.
	///
	/// There is an additional pass that interrogates the set for missing cards and if a missing card appears anywhere in the
	/// history, it is attempted to be inserted into the result set at the appropriate location.
	///
	/// If at any point during this process, something cannot be calculated or resolved, then the default action is to abort and
	/// return a failure (`nil`).
	private func merge() -> ConsolidatedLinks?
	{
		// Ensure we have a deck format
		guard let deckFormat = deckFormat else { return nil }

		// Ensure we have some history
		if entries.count == 0 { return nil }

		// Build our link matrix
		let linkMatrix = buildLinkMatrix(deckFormat: deckFormat, entries: entries)

		guard let consolidated = consolidateLinks(deckFormat: deckFormat, linkMatrix: linkMatrix) else
		{
			// We return `nil` here since we know something is wrong
			return nil
		}

		// If we have a full deck, we're done
		//
		// Keep in mind, our consolidated list includes the head, which is just a lead in, so we account for this in the test
		if consolidated.count - 1 == deckFormat.maxCardCount
		{
			return consolidated
		}

		guard let finalConsolidated = findMissing(deckFormat: deckFormat, linkMatrix: linkMatrix, foundCards: consolidated) else
		{
			// We return `nil` here since we know something is wrong
			return nil
		}

		return finalConsolidated
	}

	/// Build a matrix of [source x link_to_target] from the full set of history entries
	///
	/// The rows in the matrix are indexed by the card's index. Note that we include two additional indices here, a head and tail
	/// index, which allows us to link to the first card and from the last card. These special indices are defined as the indices
	/// immediately following the actual card indices for the given `deckFormat`.
	private func buildLinkMatrix(deckFormat: DeckFormat, entries: [Entry]) -> LinkMatrix
	{
		// The maximum number of indices allowed for the type
		let maxIndexCount = 1 << (MemoryLayout<UInt8>.size * 8)

		// If you hit this assert, your deck format has too many cards and/or does have room for the head & tail reserved indices
		assert(deckFormat.maxCardCountWithReversed + 2 < maxIndexCount)

		// Our head and tail represent two special indices that folloow the real card indices
		cardIndexHead = UInt8(deckFormat.maxCardCountWithReversed)
		cardIndexTail = cardIndexHead + 1

		// It is expensive to determine the number of links, so we go with the maximum possible
		linkMatrix.ensureReservation(rowCapacity: maxIndexCount, colCapacity: Int(cardIndexTail))

		// We visit every entry in the history
		for entry in entries
		{
			// Sanity check that this entry isn't empty
			assert(entry.count != 0)
			if entry.count == 0 { continue }

			// We always start with a head element
			var sourceIndex = Int(cardIndexHead)

			// Visit each index in this history entry, looking for targets that the current source points to
			//
			// Note how we loop one past the last index, which we'll use as the tail
			for i in 0...entry.indices.count
			{
				// Our target index, which becomes `cardIndexTail` when we reach the very end
				let targetIndex = i == entry.indices.count ? cardIndexTail : entry.indices[i]

				// See if the current source has a link to this target
				var found = false
				for j in 0..<linkMatrix.colCount(row: sourceIndex)
				{
					if linkMatrix[sourceIndex, j].target == targetIndex
					{
						// This source has a link to this target, so update the count by adding the current histgory entry's count
						linkMatrix[sourceIndex, j].count += entry.count
						found = true
						break
					}
				}

				// This source doesn't yet have a link to this target, so add one (making sure to use the history entry's count)
				if !found
				{
					linkMatrix.add(toRow: sourceIndex, value: Link(source: UInt8(sourceIndex), target: targetIndex, count: entry.count))
				}

				// Roll through `source` -> `target`
				sourceIndex = Int(targetIndex)
			}
		}

		dumpLinkMatrix(heading: "History link matrix:", deckFormat: deckFormat, linkMatrix: linkMatrix)
		return linkMatrix
	}

	/// Consolidate the link matrix into an ordered array of single links
	///
	/// Note that the array returned will start with a HEAD entry that is not part of the actual indices
	private func consolidateLinks(deckFormat: DeckFormat, linkMatrix: LinkMatrix) -> ConsolidatedLinks?
	{
		// Ensure we have enough space in our consolidated links to account for a full deck plus our head & tail
		consolidatedLinks.ensureReservation(capacity: deckFormat.maxCardCountWithReversed + 2)
		consolidatedLinks.removeAll()

		// All cards are missing until they are found
		missingIndices.ensureReservation(capacity: deckFormat.maxCardCountWithReversed + 2)
		missingIndices.initialize(to: true, count: deckFormat.maxCardCountWithReversed + 2)

		var curIndex = Int(cardIndexHead)

		while curIndex != Int(cardIndexTail)
		{
			// If this card is already found, we have a loop
			if !missingIndices[curIndex]
			{
				gLogger.badResolve("consolidateLinks: Loop detected")
				return nil
			}

			// Find the single, largest link from `curIndex`
			guard let maxLink = findMaxLink(forIndex: curIndex) else
			{
				// Inconclusive - we have too few/many matching max counts and cannot decide which is correct
				if gLogger.isSet(LogLevel.BadResolve)
				{
					let faceCode = curIndex == Int(cardIndexHead) ? "HEAD" : curIndex == Int(cardIndexTail) ? "TAIL" : deckFormat.faceCodesNdo[curIndex]
					gLogger.badResolve("consolidateLinks: Inconclusive, too many maximum links for card \(faceCode) ---------------------------------------------------")
					gLogger.execute(with: .Resolve)
					{
						self.logHistory()
						self.dumpLinkMatrix(heading: "Consolidated links leading to inconclusive result:", deckFormat: deckFormat, linkMatrix: linkMatrix)
					}
					gLogger.badResolve("------------------------------------------------------------------------------------------------------------------------------------")
					gLogger.badResolve("")
				}
				return nil
			}

			// Mark it as found and add it
			missingIndices[Int(maxLink.source)] = false
			consolidatedLinks.add(maxLink)

			curIndex = Int(maxLink.target)
		}

		dumpConsolidatedLinks(heading: "History consolidated links:", deckFormat: deckFormat, consolidatedLinks: consolidatedLinks)
		return consolidatedLinks
	}

	/// Returns the link (from `linkMatrix`) with the highest count, or `nil` if no maximum could be determined
	///
	/// This method uses extra logic to help determine a winner if there is a tie for the maximum. This logic simply determines
	/// if one of the winners points to the other, and if so it returns the link that points to the other. The reasoning for this
	/// is simple: If the cards are supposed to be 4H->5H->6H but "5H" is missed in half of the cases, then 4H will point to 5H
	/// and 6H an equal number of times. Using this test, 5H should point to 6H, and 6H should not point to 5H. If these conditions
	/// are met, then the tie is considered resolved.
	@inline(__always) private func findMaxLink(forIndex index: Int) -> Link?
	{
		let count = linkMatrix.colCount(row: index)
		var maxLink = linkMatrix[index, 0]
		var maxCount = 1
		for i in 1..<count
		{
			let otherLink = linkMatrix[index, i]
			if otherLink.count > maxLink.count
			{
				maxLink = otherLink
				maxCount = 1
			}
			else if otherLink.count == maxLink.count
			{
				// We have a tie... does one link to the other? If so, then that is the new max
				let maxToOther = linkExists(from: maxLink.target, to: otherLink.target)
				let otherToMax = linkExists(from: otherLink.target, to: maxLink.target)

				// If the flags are the same, then:
				//
				//     (a) neither max points to the other
				//     (b) they both point to each other
				//
				// Either way, leave things as they are (tracking the count) so this can be marked as inconclusive if there isn't
				// a better maximum.
				if otherToMax == maxToOther
				{
					maxCount += 1
				}
				// If other points to the current max, it wins the tie
				else if otherToMax && !maxToOther
				{
					maxLink = otherLink
					maxCount = 1
				}
				// Otherwise, the current max is our winner and we do nothing
				// else if !otherToMax && maxToOther
				// {
				// }
			}
		}

		if maxCount != 1 { return nil }
		return maxLink
	}

	/// Determines if `source` links to `target` within the `linkMatrix`
	///
	/// Returns `true` if there is a link from `source` to `target`, otherwise `false`
	@inline(__always) private func linkExists(from source: UInt8, to target: UInt8) -> Bool
	{
		let iSource = Int(source)
		let count = linkMatrix.colCount(row: iSource)
		for i in 0..<count
		{
			if linkMatrix[iSource, i].target == target
			{
				return true
			}
		}

		return false
	}

	/// Locate cards that were seen in the history but not part of the `foundCards` set and attempt to insert them at the
	/// appropriate position in the list.
	///
	/// During this process, care is taken to ensure that the counts of the affected cards is preserved, as this is important for
	/// calculating the confidence factor.
	private func findMissing(deckFormat: DeckFormat, linkMatrix: LinkMatrix, foundCards: ConsolidatedLinks) -> ConsolidatedLinks?
	{
		gLogger.resolve("Trying to find missing...")

		var newFoundCards = foundCards

		let missingCardPopularityCount = (FixedPoint(entries.count) * Config.analysisMissingCardPopularity).ceil()

		// Loop through all of the missing cards
		for missingIndex in 0..<deckFormat.maxCardCountWithReversed
		{
			// We only care about missing cards
			if !missingIndices[missingIndex] { continue }

			// Ensure we only find missing cards that do not have a found reversed counterpart
			if deckFormat.reversible
			{
				if missingIndex >= deckFormat.maxCardCount
				{
					if !missingIndices[missingIndex - deckFormat.maxCardCount] { continue }
				}
				else
				{
					if !missingIndices[missingIndex + deckFormat.maxCardCount] { continue }
				}
			}

			// Visit all the links for this missing card
			var bestTestLink = Link(source: 0, target: 0, count: 0)
			var bestMissingCardLink = Link(source: 0, target: 0, count: 0)
			var bestTestLinkCount = 0
			var bestFoundCardIndex = 0
			for missingCardLinkIndex in 0..<linkMatrix.colCount(row: missingIndex)
			{
				let missingCardLink = linkMatrix[missingIndex, missingCardLinkIndex]

				// Sanity check
				assert(Int(missingCardLink.source) == missingIndex)

				// Find found cards that link to this missing card's target
				for foundCardIndex in 0..<newFoundCards.count
				{
					let foundCardLink = newFoundCards[foundCardIndex]
					if foundCardLink.target != missingCardLink.target { continue }

					// Scan all of this found card's links and see if it also links to the missing card
					for i in 0..<linkMatrix.colCount(row: Int(foundCardLink.source))
					{
						let testLink = linkMatrix[Int(foundCardLink.source), i]

						// Does this found card also link to the missing card?
						if testLink.target == missingCardLink.source
						{
							if testLink.count > bestTestLink.count
							{
								bestTestLink = testLink
								bestMissingCardLink = missingCardLink
								bestFoundCardIndex = foundCardIndex
								bestTestLinkCount = 1
							}
							else if testLink.count == bestTestLink.count
							{
								bestTestLinkCount += 1
							}
						}
					}
				}
			}

			// The card is actually missing (nobody links to it)
			if bestTestLinkCount == 0
			{
				continue
			}

			// Inconclusive - we have too many matching max counts and cannot decide which is correct
			if bestTestLinkCount != 1
			{
				gLogger.badResolve("findMissing: Inconclusive (bestTestLinkCount needs to be '1' but is '\(bestTestLinkCount)')")
				return nil
			}

			// Ensure enough found cards link to this missing card
			if bestTestLink.count < missingCardPopularityCount
			{
				continue
			}

			if gLogger.isSet(LogLevel.Resolve)
			{
				let faceCodeA = bestTestLink.source == cardIndexHead ? "HEAD" : bestTestLink.source == cardIndexTail ? "TAIL" : deckFormat.faceCodesNdo[Int(bestTestLink.source)]
				let faceCodeB = bestMissingCardLink.source == cardIndexHead ? "HEAD" : bestMissingCardLink.source == cardIndexTail ? "TAIL" : deckFormat.faceCodesNdo[Int(bestMissingCardLink.source)]
				let faceCodeC = bestMissingCardLink.target == cardIndexHead ? "HEAD" : bestMissingCardLink.target == cardIndexTail ? "TAIL" : deckFormat.faceCodesNdo[Int(bestMissingCardLink.target)]
				gLogger.resolve("Inserting missing card: \(faceCodeA)->[\(faceCodeB)]->\(faceCodeC)")
			}

			// Replace the found link with the one that links to the missing card
			newFoundCards[bestFoundCardIndex] = bestTestLink
			newFoundCards.insert(before: bestFoundCardIndex+1, value: bestMissingCardLink)
		}

		dumpConsolidatedLinks(heading: "History final result:", deckFormat: deckFormat, consolidatedLinks: newFoundCards)
		return newFoundCards
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	// Cleanup history - remove all entries older than the max age defined by `Config.analysisMaxHistoryAgeMS`
	private func prune()
	{
		for i in 0..<entries.count
		{
			entries[i].removeOldEntries(maxHistoryAgeMS: Config.analysisMaxHistoryAgeMS)
		}

		// Wipe out empty history entries
		entries = entries.filter {$0.count > 0}
	}

	/// Reset the analyzer completely
	///
	/// This wipes out all history
	///
	/// Use this when a new deck is known to be introduced
	public func reset()
	{
		entries.removeAll()
	}

	/// Confidence example:
	///     If we have...
	///
	///         35 history entries
	///         33 average link count
	///
	///     then...
	///
	///         33 / 35 = 0.9428571429
	public func calcConfidence() -> Real
	{
		var linkCount = 0
		var linkSum = 0

		for i in 0..<consolidatedLinks.count
		{
			linkSum += consolidatedLinks[i].count
			linkCount += 1
		}

		let linkAverage = Real(linkSum) / Real(linkCount)
		return linkAverage / Real(calcTotalHistorySize()) * 100
	}

	/// Returns the total size of the history, returning the sum of the count of all entries
	public func calcTotalHistorySize() -> Int
	{
		var historyTotalSize = 0
		for i in 0..<entries.count
		{
			historyTotalSize += entries[i].count
		}

		return historyTotalSize
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Debug
	// -----------------------------------------------------------------------------------------------------------------------------

	private func dumpLinkMatrix(heading: String, deckFormat: DeckFormat, linkMatrix: LinkMatrix)
	{
		if !gLogger.isSet(LogLevel.Resolve) { return }

		gLogger.resolve(heading)
		var line = "  "
		for source in 0..<linkMatrix.rowCount()
		{
			if linkMatrix.colCount(row: source) == 0 { continue }

			let faceCode = source == Int(cardIndexHead) ? "HEAD" : source == Int(cardIndexTail) ? "TAIL" : deckFormat.faceCodesNdo[Int(source)]
			line += "\(faceCode)"

			for i in 0..<linkMatrix.colCount(row: source)
			{
				let link = linkMatrix[source, i]
				let faceCode = link.target == cardIndexHead ? "HEAD" : link.target == cardIndexTail ? "TAIL" : deckFormat.faceCodesNdo[Int(link.target)]

				line += "->\(faceCode):\(link.count)"
			}
			line += " "
		}

		gLogger.resolve(line)
	}

	private func dumpConsolidatedLinks(heading: String, deckFormat: DeckFormat, consolidatedLinks: ConsolidatedLinks)
	{
		if !gLogger.isSet(LogLevel.Resolve) { return }

		gLogger.resolve(heading)
		var line = ""
		for i in 0..<consolidatedLinks.count
		{
			let link = consolidatedLinks[i]
			let faceCode = link.source == cardIndexHead ? "HEAD" : link.source == cardIndexTail ? "TAIL" : deckFormat.faceCodesNdo[Int(link.source)]
			line += "\(faceCode):\(link.count) "
		}

		gLogger.resolve(line)
	}

	// Log the history
	public func logHistory()
	{
		logHistory(withHistory: entries)
	}

	// Log the history
	private func logHistory(withHistory entries: [Entry])
	{
		gLogger.resolve("History:")
		for entry in entries
		{
			if let faceCodes = deckFormat?.getFaceCodes(indices: entry.indices).joined(separator: " ")
			{
				gLogger.resolve("\(entry.count.toString(3)): \(faceCodes)")
			}
		}
	}

	public func distributionString(matchingIndices: [UInt8]? = nil) -> String
	{
		var result = ""
		var index = 0
		for entry in entries
		{
			let thisOne = (matchingIndices != nil && entry.indices == matchingIndices!) ? ">" : " "
			let indexStr = String(format: "%3d", arguments: [index + 1])
			let cardCount = String(format: "%2d", arguments: [entry.indices.count + 1])
			let asciiBar = String(repeating: "o", count: entry.count)
			result += "  \(thisOne) \(indexStr) (\(cardCount)): \(asciiBar)\n"
			index += 1
		}

		return result
	}
}
