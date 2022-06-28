//
//  ResultStats.swift
//  Seer
//
//  Created by Paul Nettle on 5/27/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// Stores and allows control over statistics on the performance of final results
public struct ResultStats
{
	//
	// Deck search
	//

	/// Number of decks found
	var searchDecodableCount = 0

	/// The total number of frames that were ignored from the search (ex: too small)
	var searchTooSmallCount = 0

	/// The total number of frames that we were unable to find a deck to scan
	var searchNotFoundCount = 0

	/// Total number of decks found (includes decodable and too small)
	var searchFoundCount: Int { return searchDecodableCount + searchTooSmallCount }

	/// The total number of searches
	var searchTotalCount: Int { return searchFoundCount + searchNotFoundCount }

	/// Percentage of decks found from all searches
	var searchFoundPercent: Real { return searchTotalCount == 0 ? 0 : Real(searchFoundCount) / Real(searchTotalCount) }

	//
	// Deck decoding
	//

	/// The number of decoded frames (correct or not)
	var decodeDecodedCount = 0

	/// The total number of frames that were ignored during decoding (ex: not sharp enough)
	var decodeBlurryCount = 0

	/// The total number of frames that contained too few cards
	var decodeTooFewCardsCount = 0

	/// The total number of frames that encountered a general decode failure
	var decodeGeneralFailureCount = 0

	/// The total number of decodes
	var decodeTotalCount: Int { return decodeDecodedCount + decodeBlurryCount + decodeTooFewCardsCount + decodeGeneralFailureCount }

	/// The percentage of total frames that were decoded
	var decodeDecodedPercent: Real { return decodeTotalCount == 0 ? 0 : Real(decodeDecodedCount) / Real(decodeTotalCount) }

	//
	// Analyzer stats
	//

	/// Total Fail history results
	var analyzedFailureCount = 0

	/// Total inconclusive results
	var analyzedInconclusiveCount = 0

	/// Total insufficient history results
	var analyzedInsufficientHistoryCount = 0

	/// Total insufficient confidence results
	var analyzedInsufficientConfidenceCount = 0

	/// Total low-confidence results (these are reported)
	var analyzedReportLowConfidenceCount = 0

	/// Total high-confidence results (these are reported)
	var analyzedReportHighConfidenceCount = 0

	/// Total unsufficient results: no confidence, very low low confidence, or determined to be probably incorrect
	var analyzedInsufficientTotal: Int { return analyzedInsufficientHistoryCount + analyzedInsufficientConfidenceCount }

	/// Total reports: Suggested to report to the user, with either low or high confidence
	var analyzedReportsTotal: Int { return analyzedReportLowConfidenceCount + analyzedReportHighConfidenceCount }

	/// Total number of results analyzed
	var analyzedTotal: Int { return analyzedInconclusiveCount + analyzedInsufficientTotal + analyzedReportsTotal + analyzedFailureCount }

	/// Percentage of reports from total number of analyzed results
	var analyzedReportPercent: Real { return analyzedTotal == 0 ? 0 : Real(analyzedReportsTotal) / Real(analyzedTotal) }

	//
	// Validation (decoding)
	//

	/// The number of missed cards
	var validatedDecodeMissedCardCount = 0

	/// The number of out of order cards
	var validatedDecodeOutOfOrderCardCount = 0

	/// The number of correct results
	var validatedDecodeCorrectCount = 0

	/// The number of incorrect results
	var validatedDecodeIncorrectCount = 0

	/// The total number of correct + incorrect decodes
	var validatedDecodeTotalCount: Int { return validatedDecodeCorrectCount + validatedDecodeIncorrectCount }

	/// The percentage of correct decodes
	var validatedDecodeCorrectPercent: Real { return validatedDecodeTotalCount == 0 ? 0 : Real(validatedDecodeCorrectCount) / Real(validatedDecodeTotalCount) }

	//
	// Validation (reporting)
	//

	/// The total number of incorrect reports
	var validatedReportIncorrectCount = 0

	/// The total number of correct low-confidence reports
	var validatedReportCorrectLowConfidenceCount = 0

	/// The total number of correct high-confidence reports
	var validatedReportCorrectHighConfidenceCount = 0

	/// The total number of correct reports (high + low confidence)
	var validatedReportCorrectCount: Int { return validatedReportCorrectLowConfidenceCount + validatedReportCorrectHighConfidenceCount }

	/// The total number of reports (correct + incorrect)
	var validatedReportTotalCount: Int { return validatedReportCorrectCount + validatedReportIncorrectCount }

	/// The percentage of correct reports
	var validatedReportCorrectPercent: Real { return validatedReportTotalCount == 0 ? 0 : Real(validatedReportCorrectCount) / Real(validatedReportTotalCount) }

	//
	// Validation (overall scanning process)
	//

	/// Total number of scans considered valid
	var validatedScanCorrectCount: Int { return validatedDecodeCorrectCount + decodeBlurryCount + decodeTooFewCardsCount + searchTooSmallCount }

	/// Total number of scans considered invalid
	var validatedScanIncorrectCount: Int { return validatedDecodeIncorrectCount + decodeTooFewCardsCount + decodeGeneralFailureCount }

	/// Total number of scans performed
	var validatedScanTotalCount: Int { return validatedScanCorrectCount + validatedScanIncorrectCount }

	/// Percentage of valid scans from found decks
	var validatedScanCorrectPercent: Real { return validatedScanTotalCount == 0 ? 0 : Real(validatedScanCorrectCount) / Real(validatedScanTotalCount) }

	//
	// Total number of frames processed
	//

	public var frameCount = 0

	/// Reset the statistics
	mutating func reset()
	{
		searchDecodableCount = 0
		searchTooSmallCount = 0
		searchNotFoundCount = 0

		decodeDecodedCount = 0
		decodeBlurryCount = 0
		decodeTooFewCardsCount = 0
		decodeGeneralFailureCount = 0

		analyzedFailureCount = 0
		analyzedInconclusiveCount = 0
		analyzedInsufficientHistoryCount = 0
		analyzedInsufficientConfidenceCount = 0
		analyzedReportLowConfidenceCount = 0
		analyzedReportHighConfidenceCount = 0

		validatedDecodeCorrectCount = 0
		validatedDecodeIncorrectCount = 0
		validatedDecodeMissedCardCount = 0
		validatedDecodeOutOfOrderCardCount = 0

		validatedReportIncorrectCount = 0
		validatedReportCorrectLowConfidenceCount = 0
		validatedReportCorrectHighConfidenceCount = 0

		frameCount = 0
	}

	/// Dumps a formatted line of text for deck search statistics
	public func generateSearchStatsText() -> String
	{
		let searchPercentStr = String(format: "%5.1f%%%%", arguments: [Float(searchFoundPercent * Real(100.0))]).padding(toLength: 7, withPad: " ", startingAt: 0)
		return String(format: "\(searchPercentStr) %4d - NotFound(%d) - TooSmall(%d) >> Found(%d)", arguments:
			[searchTotalCount,
			 searchNotFoundCount,
			 searchTooSmallCount,
			 searchDecodableCount])
	}

	/// Dumps a formatted line of text for decoding statistics
	public func generateDecodeStatsText() -> String
	{
		let decodeedPercentStr = String(format: "%5.1f%%%%", arguments: [Float(decodeDecodedPercent * Real(100.0))]).padding(toLength: 7, withPad: " ", startingAt: 0)
		return String(format: "\(decodeedPercentStr) %4d - Blur(%d) - Few(%d) - Fail(%d) >> Decoded(%d)", arguments:
			[decodeTotalCount,
			 decodeBlurryCount,
			 decodeTooFewCardsCount,
			 decodeGeneralFailureCount,
			 decodeDecodedCount])
	}

	/// Dumps a formatted line of text for analyzer statistics
	public func generateAnalyzerStatsText() -> String
	{
		let reportPercentStr = String(format: "%5.1f%%%%", arguments: [Float(analyzedReportPercent * Real(100.0))]).padding(toLength: 7, withPad: " ", startingAt: 0)
		return String(format: "\(reportPercentStr) %4d - F(%d) - I(%d) - Insf(Hist:%d + Conf:%d) >> Report(%d = H:%d + L:%d)", arguments:
			[analyzedTotal,
			 analyzedFailureCount,
			 analyzedInconclusiveCount,
			 analyzedInsufficientHistoryCount,
			 analyzedInsufficientConfidenceCount,
			 analyzedReportsTotal,
			 analyzedReportHighConfidenceCount,
			 analyzedReportLowConfidenceCount])
	}

	/// Dumps a formatted line of text for validated decoding statistics
	public func generateValidatedDecodeCorrectStatsText() -> String
	{
		let correctPercentStr = String(format: "%5.1f%%%%", arguments: [Float(validatedDecodeCorrectPercent * Real(100.0))]).padding(toLength: 7, withPad: " ", startingAt: 0)
		return String(format: "\(correctPercentStr) %4d - Fail(%d) - Missed(%d) - OutOfOrder(%d) >> Correct(%d)", arguments:
			[decodeDecodedCount,
			 analyzedFailureCount,
			 validatedDecodeMissedCardCount,
			 validatedDecodeOutOfOrderCardCount,
			 validatedDecodeCorrectCount])
	}

	/// Dumps a formatted line of text for validated reports statistics
	public func generateValidatedReportsStatsText() -> String
	{
		let reportPercentStr = String(format: "%5.1f%%%%", arguments: [Float(validatedReportCorrectPercent * Real(100.0))]).padding(toLength: 7, withPad: " ", startingAt: 0)
		return String(format: "\(reportPercentStr) %4d - Incorrect(%d) >> Correct(%d = H:%d + L:%d)", arguments:
			[validatedReportTotalCount,
			 validatedReportIncorrectCount,
			 validatedReportCorrectCount,
			 validatedReportCorrectHighConfidenceCount,
			 validatedReportCorrectLowConfidenceCount])
	}

	/// Dumps a formatted line of text for validated overall scanning statistics
	public func generateValidatedOverallStatsText() -> String
	{
		let scanPercentStr = String(format: "%5.1f%%%%", arguments: [Float(validatedScanCorrectPercent * Real(100.0))]).padding(toLength: 7, withPad: " ", startingAt: 0)
		return String(format: "\(scanPercentStr) %4d - Incorrect(%d) >> Correct(%d)", arguments:
			[frameCount,
			 validatedScanIncorrectCount,
			 validatedScanCorrectCount])
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Debug
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Draw a vertical bar at a given horizontal position that is scaled to a portion of the height of the image based on a
	/// unit scalar percentage
	///
	/// If the input `x` coordinate is negative, then it is relative to the right edge of the image.
	func debugDrawVerticalMeter(debugBuffer: DebugBuffer?, x inX: Int, percentageUnitScalar: Real, color: Color)
	{
		if debugBuffer == nil { return }

		var x = inX
		if x < 0 { x = debugBuffer!.width - 1 + x }

		let h = debugBuffer!.height
		let barHeight = Int(Real(h) * percentageUnitScalar)

		let r = Rect<Int>(minX: x - 2, minY: h - 1 - barHeight, maxX: x + 2, maxY: h - 1)
		r.fill(to: debugBuffer, color: color)
	}

	/// Draw a vertical meter on the right side representing the percentage of correct scans
	public func debugDrawResultsBar(debugBuffer: DebugBuffer?)
	{
		debugDrawVerticalMeter(debugBuffer: debugBuffer, x: -kDebugDecodeOutlineThickness / 2, percentageUnitScalar: validatedScanCorrectPercent, color: kDebugDecodeCorrectPercentBarColor)
	}
}
