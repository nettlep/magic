//
//  AnalysisResult.swift
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

/// The result of an analysis of a scanned deck
public enum AnalysisResult
{
	/// The scan failed, either due to a failed search or decode
	case Fail(deckSearchResult: SearchResult, decodeResult: DecodeResult?)

	/// A deck was scanned, but the analysis result was inconclusive
	case Inconclusive(deckSearchResult: SearchResult, decodeResult: DecodeResult, deck: Deck)

	/// A deck was scanned, but there wasn't enough history to determine confidence
	case InsufficientHistory(deckSearchResult: SearchResult, decodeResult: DecodeResult, deck: Deck)

	/// A deck was scanned, but the confidence factor is too low to be considered usable
	case InsufficientConfidence(deckSearchResult: SearchResult, decodeResult: DecodeResult, confidence: Real, deck: Deck)

	/// A deck was scanned and meets the minimum confidence factor requirement for a usable deck
	case SuccessLowConfidence(deckSearchResult: SearchResult, decodeResult: DecodeResult, confidence: Real, deck: Deck)

	/// A deck was scanned and meets or exceeds the 'high confidence' factor
	case SuccessHighConfidence(deckSearchResult: SearchResult, decodeResult: DecodeResult, confidence: Real, deck: Deck)

	/// Returns the deck search result from either a successful or failed scan
	public var deckSearchResult: SearchResult
	{
		switch self
		{
			case .Fail(let deckSearchResult, _):
				return deckSearchResult
			case .Inconclusive(let deckSearchResult, _, _):
				return deckSearchResult
			case .InsufficientHistory(let deckSearchResult, _, _):
				return deckSearchResult
			case .InsufficientConfidence(let deckSearchResult, _, _, _):
				return deckSearchResult
			case .SuccessLowConfidence(let deckSearchResult, _, _, _):
				return deckSearchResult
			case .SuccessHighConfidence(let deckSearchResult, _, _, _):
				return deckSearchResult
		}
	}

	/// Returns the decoder result from either a successful or failed scan, if available
	public var decodeResult: DecodeResult?
	{
		switch self
		{
			case .Fail(_, let decodeResult):
				return decodeResult
			case .Inconclusive(_, let decodeResult, _):
				return decodeResult
			case .InsufficientHistory(_, let decodeResult, _):
				return decodeResult
			case .InsufficientConfidence(_, let decodeResult, _, _):
				return decodeResult
			case .SuccessLowConfidence(_, let decodeResult, _, _):
				return decodeResult
			case .SuccessHighConfidence(_, let decodeResult, _, _):
				return decodeResult
		}
	}

	/// Returns the confidence factor of a successful scan, if available
	public var confidenceFactor: Real?
	{
		switch self
		{
			case .InsufficientConfidence(_, _, let confidence, _):
				return confidence
			case .SuccessLowConfidence(_, _, let confidence, _):
				return confidence
			case .SuccessHighConfidence(_, _, let confidence, _):
				return confidence
			default:
				return nil
		}
	}

	/// Returns the deck of a successful scan, if available
	public var deck: Deck?
	{
		switch self
		{
			case .Inconclusive(_, _, let deck):
				return deck
			case .InsufficientHistory(_, _, let deck):
				return deck
			case .InsufficientConfidence(_, _, _, let deck):
				return deck
			case .SuccessLowConfidence(_, _, _, let deck):
				return deck
			case .SuccessHighConfidence(_, _, _, let deck):
				return deck
			default:
				return nil
		}
	}

	/// Returns true if the result is a .Fail result, otherwise false
	public var isFail: Bool
	{
		if case .Fail = self { return true }
		return false
	}

	/// Returns true if the result is a .Inconclusive result, otherwise false
	public var isInconclusive: Bool
	{
		if case .Inconclusive = self { return true }
		return false
	}

	/// Returns true if the result is a .InsufficientHistory result, otherwise false
	public var isInsufficientHistory: Bool
	{
		if case .InsufficientHistory = self { return true }
		return false
	}

	/// Returns true if the result is a .InsufficientConfidence result, otherwise false
	public var isInsufficientConfidence: Bool
	{
		if case .InsufficientConfidence = self { return true }
		return false
	}

	/// Returns true if the result is a .SuccessLowConfidence result, otherwise false
	public var isSuccessLowConfidence: Bool
	{
		if case .SuccessLowConfidence = self { return true }
		return false
	}

	/// Returns true if the result is a .SuccessHighConfidence result, otherwise false
	public var isSuccessHighConfidence: Bool
	{
		if case .SuccessHighConfidence = self { return true }
		return false
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Parsable description
// ---------------------------------------------------------------------------------------------------------------------------------

extension AnalysisResult
{
	/// Returns a string constant useful for reporting and parsing
	public var parsableDescription: String
	{
		switch self
		{
			case let .Fail(deckSearchResult, decodeResult):
				if deckSearchResult.isDecodable
				{
					if let result = decodeResult
					{
						return "\(result.parsableDescription)"
					}
					else
					{
						return "NoDecodeResult"
					}
				}
				else
				{
					return "\(deckSearchResult.parsableDescription)"
				}

			case .Inconclusive:
				return "Inconslusive"

			case .InsufficientHistory:
				return "NotEnoughHistory"

			case .InsufficientConfidence:
				return "NotEnoughConfidence"

			case .SuccessLowConfidence:
				return "ResultLowConfidence"

			case .SuccessHighConfidence:
				return "ResultHighConfidence"
		}
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension AnalysisResult: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		var desc = ""
		switch self
		{
			case let .Fail(deckSearchResult, decodeResult):
				desc = "Failed: "
				if deckSearchResult.isDecodable
				{
					if let result = decodeResult
					{
						desc += "\(result)"
					}
					else
					{
						desc += " [nil decode result]"
					}
				}
				else
				{
					desc += "\(deckSearchResult)"
				}

			case .Inconclusive:
				desc = "Inconclusive"

			case .InsufficientHistory:
				desc = "Insufficient history"

			case let .InsufficientConfidence(_, _, confidence, deck):
				desc = "Insufficient confidence (\(confidence))"

				// Is this actually the correct answer?
				var missingCards = [String]()
				var unorderedCards = [String]()
				var scannedComparison = [String]()
				var knownComparison = [String]()
				if deck.validateAgainstKnownDeck(missingCards: &missingCards, unorderedCards: &unorderedCards, scannedComparison: &scannedComparison, knownComparison: &knownComparison)
				{
					desc += " (correct)"
				}
				else
				{
					desc += " (incorrect)"
				}

				//desc += "\n    \(deck.faceCodes(faceCodes: deck.getFaceCodes(resolvedIndices: deck.resolvedIndices)))"

			case let .SuccessLowConfidence(_, _, confidence, deck):
				// Is this actually the correct answer?
				var missingCards = [String]()
				var unorderedCards = [String]()
				var scannedComparison = [String]()
				var knownComparison = [String]()
				if deck.validateAgainstKnownDeck(missingCards: &missingCards, unorderedCards: &unorderedCards, scannedComparison: &scannedComparison, knownComparison: &knownComparison)
				{
					desc = "Correct: "
				}
				else
				{
					desc = "Incorrect: "
				}

				desc += "Low confidence (\(confidence))"
				//desc += "\n    \(deck.faceCodes(faceCodes: deck.getFaceCodes(resolvedIndices: deck.resolvedIndices)))"

			case let .SuccessHighConfidence(_, _, confidence, deck):
				// Is this actually the correct answer?
				var missingCards = [String]()
				var unorderedCards = [String]()
				var scannedComparison = [String]()
				var knownComparison = [String]()
				if deck.validateAgainstKnownDeck(missingCards: &missingCards, unorderedCards: &unorderedCards, scannedComparison: &scannedComparison, knownComparison: &knownComparison)
				{
					desc = "Correct: "
				}
				else
				{
					desc = "Incorrect: "
				}

				desc += "High confidence (\(confidence))"
				//desc += "\n    \(deck.faceCodes(faceCodes: deck.getFaceCodes(resolvedIndices: deck.resolvedIndices)))"
		}

		return desc
	}
}
