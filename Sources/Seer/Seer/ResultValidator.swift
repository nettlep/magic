//
//  ResultValidator.swift
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

/// Performs validation on decoded deck results, using the known deck order from the test harness
public final class ResultValidator
{
	// We need a public initializer in order to use this externally
	public init()
	{
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Performs full result validation against a known test deck order in the testing harness
	///
	/// This method requires a valid analysisResult with a DecodeResult that contains a Deck. If any of these conditions are not
	/// true, the validation returns falae.
	///
	/// Returns true if the results were determined to be correct
	public func validateResults(debugBuffer: DebugBuffer?, codeDefinition: CodeDefinition, stats: inout ResultStats, analysisResult: AnalysisResult) -> Bool
	{
		let result = internalValidateResults(debugBuffer: debugBuffer, codeDefinition: codeDefinition, stats: &stats, analysisResult: analysisResult)

		if Config.debugDrawScanResults
		{
			stats.debugDrawResultsBar(debugBuffer: debugBuffer)
		}

		return result
	}

	/// Internal validation - see `validateResults` for more info
	private func internalValidateResults(debugBuffer: DebugBuffer?, codeDefinition: CodeDefinition, stats: inout ResultStats, analysisResult: AnalysisResult) -> Bool
	{
		// Don't process known failures
		if analysisResult.isFail { return false }

		// We need a decode result in order to validate the results
		guard let decodeResult = analysisResult.decodeResult else
		{
			return false
		}

		// We really shouldn't ever be called in a situation where a deck isn't available, but it's not technically forbidden
		guard let deck = decodeResult.deck else
		{
			return false
		}

		// Is this actually the correct answer?
		var missingCards = [String]()
		var unorderedCards = [String]()
		var scannedComparison = [String]()
		var knownComparison = [String]()
		let validatedCorrect = deck.validateAgainstKnownDeck(missingCards: &missingCards, unorderedCards: &unorderedCards, scannedComparison: &scannedComparison, knownComparison: &knownComparison)

		let prefix = "  "
		if validatedCorrect
		{
			stats.validatedDecodeCorrectCount += 1

			if gLogger.isSet(LogLevel.Correct)
			{
				gLogger.correct("Correct scan")
			}
		}
		else
		{
			stats.validatedDecodeIncorrectCount += 1
			stats.validatedDecodeMissedCardCount += missingCards.count
			stats.validatedDecodeOutOfOrderCardCount += unorderedCards.count

			if gLogger.isSet(LogLevel.Incorrect)
			{
				gLogger.incorrect("Incorrect scan")
				gLogger.incorrect(formattedValidationResults(deck: deck, missingCards: missingCards, unorderedCards: unorderedCards, scannedComparison: scannedComparison, knownComparison: knownComparison, prefix: prefix))
			}
		}

		// Let the user know it's good/bad
		if Config.debugDrawScanResults
		{
			if let debugBuffer = debugBuffer
			{
				if validatedCorrect
				{
					let r = Rect<Int>(x: 0, y: 0, width: debugBuffer.width, height: debugBuffer.height)
					r.outline(to: debugBuffer, color: kDebugDecodeValidationPerfectBorderColor, thickness: kDebugDecodeOutlineThickness, padding: kDebugDecodeOutlineThickness * 4)
				}
				else
				{
					let r = Rect<Int>(x: 0, y: 0, width: debugBuffer.width, height: debugBuffer.height)
					r.outline(to: debugBuffer, color: kDebugDecodeValidationFailedBorderColor, thickness: kDebugDecodeOutlineThickness, padding: kDebugDecodeOutlineThickness * 4)
				}
			}
		}

		// If we're searching for a deck and we aren't currently rendering from the work buffer (which means we just processed a
		// real frame of video) then halt the video.
		if validatedCorrect && Config.debugPauseOnCorrectDecode && !Config.isReplayingFrame
		{
			Config.debugPauseOnCorrectDecode = false
			Config.pauseRequested = true
		}
		else if !validatedCorrect && Config.debugPauseOnIncorrectDecode && !Config.isReplayingFrame
		{
			Config.debugPauseOnIncorrectDecode = false
			Config.pauseRequested = true

			gLogger.execute(with: LogLevel.Result.rawValue | LogLevel.Decode.rawValue | LogLevel.Resolve.rawValue)
			{
				if let markLines = analysisResult.deckSearchResult.markLines
				{
					_ = Decoder.decode(debugBuffer: debugBuffer, markLines: markLines, deckFormat: codeDefinition.format)
				}

				let validationResultString = self.formattedValidationResults(deck: deck, missingCards: missingCards, unorderedCards: unorderedCards, scannedComparison: scannedComparison, knownComparison: knownComparison, prefix: "  ")
				gLogger.incorrect("Incorrect scan")
				gLogger.incorrect("")
				gLogger.incorrect(validationResultString)
			}
		}

		// If we don't have a confidence factor, we need to stop here (none of the following debug code will apply)
		guard let confidenceFactor = analysisResult.confidenceFactor else
		{
			return false
		}

		// Provide some debug feedback if we meet the minimum confidence (which means we'll return a deck to the user)
		if confidenceFactor >= Config.analysisMinimumConfidenceFactorThreshold
		{
			// Give some feedback if our actual returned deck is correct or not
			if debugBuffer != nil && Config.debugDrawScanResults
			{
				let cx = debugBuffer!.width / 2
				let cy = debugBuffer!.height / 2
				let hOffset = cx / 2
				let vOffset = cy / 5
				let resultValidityColor = validatedCorrect ? kDebugDecodeCorrectAnswerBorderColor : kDebugDecodeIncorrectAnswerBorderColor
				let r = Rect<Int>(minX: cx - hOffset, minY: cy - vOffset, maxX: cx + hOffset, maxY: cy + vOffset)
				r.fill(to: debugBuffer, color: resultValidityColor)
			}

			// We reported incorrectly to the user
			if !validatedCorrect
			{
				stats.validatedReportIncorrectCount += 1

				// Spit out some good debug information so we can understand why
				if gLogger.isSet(LogLevel.BadReport)
				{
					// We'll need this so we can locate the result in the history
					let deckIndices = deck.resolvedIndices

					// Log the results
					gLogger.badReport("Invalid result returned to user!")
					gLogger.badReport("")

					let validationResultString = formattedValidationResults(deck: deck, missingCards: missingCards, unorderedCards: unorderedCards, scannedComparison: scannedComparison, knownComparison: knownComparison, prefix: "  ")
					gLogger.badReport(validationResultString)

					gLogger.badReport("  History distribution:")
					gLogger.badReport("")

					gLogger.badReport(History.instance.distributionString(matchingIndices: deckIndices))
					gLogger.badReport(String(repeating: "-", count: 132))
				}
			}
			else
			{
				if confidenceFactor < Config.analysisHighConfidenceFactorThreshold
				{
					stats.validatedReportCorrectLowConfidenceCount += 1
				}
				else
				{
					stats.validatedReportCorrectHighConfidenceCount += 1
				}
			}
		}

		return validatedCorrect
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns a string containing validation results with the various cards that were mismatched/unordered/missing. An optional
	/// prefix can be provided that is prepended onto each line.
	///
	/// In addition, cards that appear missing can optionally include the bit mask for the codes as they should appear on the
	/// printed deck.
	func formattedValidationResults(deck: Deck, missingCards: [String], unorderedCards: [String], scannedComparison: [String], knownComparison: [String], prefix: String = "", includeBitMask: Bool = false) -> String
	{
		var result = ""
		result += prefix + "Missing: \(missingCards.count)" + String.kNewLine
		result += prefix + "OoOrder: \(unorderedCards.count)" + String.kNewLine

		result += prefix + "  Found: " + scannedComparison.joined(separator: " ") + String.kNewLine
		result += prefix + "  Known: " + knownComparison.joined(separator: " ") + String.kNewLine
		if missingCards.count != 0
		{
			result += prefix + "  Missing codes: "
			for missingCard in missingCards
			{
				result += "\(missingCard) "
				if includeBitMask
				{
					 result += "\(missingCard)["
					 let missingIndex = deck.format.getCardIndex(fromFaceCode: missingCard)!
					 let code = deck.format.mapIndexToCode[missingIndex]
					 result += code.binaryStringAscii(deck.format.cardCodeBitCount, reversed: true)
					 result += "]  "
				}
			}
		}

		return result
	}
}
