//
//  ScanManager.swift
//  Seer
//
//  Created by Paul Nettle on 12/30/16.
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

/// The scanning manager
///
/// This is your interface for scanning decks of marked cards
public final class ScanManager
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The sharpness factor of the current frame
	///
	/// Not used when `Config.EnableSharpnessDetection` is set to `false`
	public static var decodeSharpnessFactor: FixedPoint = 0.0

	/// Collection of statistics about our output performance
	public var resultStats = ResultStats()

	/// We'll use this to locate the deck in the image
	var deckSearch: DeckSearch

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	public init(withSize size: IVector = IVector(x: 1280, y: 720))
	{
		deckSearch = DeckSearch(size: size)
		reset()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Scans a deck from an input image and return an ordered array of card indices, if possible
	///
	/// The overall process is:
	///
	///    1. Locate the deck along with the bit marks printed on the deck
	///    2. Scan and decode the deck bits to read the card order
	///    3. Validate the results (see validateDecodedCards())
	///
	/// An AnalysisResult is returned
	public func scan(debugBuffer: DebugBuffer?, lumaBuffer: LumaBuffer, codeDefinition: CodeDefinition) -> AnalysisResult
	{
		// Perform the scan
		let scanStart = PerfTimer.trackBegin()
		let result = internalScan(debugBuffer: debugBuffer, lumaBuffer: lumaBuffer, codeDefinition: codeDefinition)
		PerfTimer.trackEnd(name: "Scan", start: scanStart)

		// Draw the mouse
		if Config.debugDrawMouseEdgeDetection
		{
			let mouseSize = 40
			let mouseSizeX = IVector(x: mouseSize, y: 0)
			let mouseSizeY = IVector(x: 0, y: mouseSize)
			let mouse = Config.mousePosition.chopToPoint()
			SampleLine(p0: mouse - mouseSizeX, p1: mouse + mouseSizeX).draw(to: debugBuffer, color: 0x80ffffff)
			SampleLine(p0: mouse - mouseSizeY, p1: mouse + mouseSizeY).draw(to: debugBuffer, color: 0x80ffffff)
		}

		if Config.debugDrawScanResults
		{
			if let debugBuffer = debugBuffer
			{
				var borderColor: Color = 0
				switch result.deckSearchResult
				{
					case .NotFound:
						break

					case .TooSmall:
						borderColor = kDeckSearchTooSmallBorderColor

					case .Decodable:
						if Config.debugDrawMarkHistogram
						{
							result.deckSearchResult.markLines?.debugDrawHistogram(debugBuffer: debugBuffer)
						}
						borderColor = kDeckSearchFoundBorderColor
				}

				if borderColor != 0
				{
					let r = Rect<Int>(x: 0, y: 0, width: debugBuffer.width, height: debugBuffer.height)
					r.outline(to: debugBuffer, color: borderColor, thickness: kDebugDecodeOutlineThickness)
				}

				if let decodeResult = result.decodeResult
				{
					var borderColor: Color = 0
					switch decodeResult
					{
						case .GeneralFailure:
							borderColor = kDebugDecodeGeneralFailureBorderColor
						case .NotSharp:
							borderColor = kDebugDecodeNotSharpBorderColor
						case .TooFewCards:
							borderColor = kDebugDecodeTooFewCardsBorderColor
						case .Decoded:
							borderColor = kDebugDecodeDecodedBorderColor
					}

					let r = Rect<Int>(x: 0, y: 0, width: debugBuffer.width, height: debugBuffer.height)
					r.outline(to: debugBuffer, color: borderColor, thickness: kDebugDecodeOutlineThickness, padding: kDebugDecodeOutlineThickness * 2)
				}
			}
		}

		return result
	}

	/// Internal scanning routine. See `scan()` for details
	private func internalScan(debugBuffer: DebugBuffer?, lumaBuffer: LumaBuffer, codeDefinition: CodeDefinition) -> AnalysisResult
	{
		resultStats.frameCount += 1

		// Debug code to skip the scanning process entirely (useful to localize perf issues during perf testing)
		// return .Fail(deckSearchResult: .NotFound, decodeResult: nil)

		#if DEBUG
		EdgeDetection.resetDebuggableEdgeDetectionSequence()
		#endif

		// Reset our sharpness factor for every frame so we don't hold on to the value on frames where it is not calculated
		ScanManager.decodeSharpnessFactor = 0

		// =-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-
		// Scan the lumaBuffer for a deck
		// =-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-

		var markLines: MarkLines?

		let searchStart = PerfTimer.trackBegin()
		let deckSearchResult = deckSearch.scanImage(debugBuffer: debugBuffer, lumaBuffer: lumaBuffer, codeDefinition: codeDefinition)

		switch deckSearchResult
		{
			case .NotFound:
				resultStats.searchNotFoundCount += 1

			case .TooSmall:
				resultStats.searchTooSmallCount += 1

			case .Decodable(let mLines):
				markLines = mLines
				resultStats.searchDecodableCount += 1
		}

		if markLines == nil
		{
			return .Fail(deckSearchResult: deckSearchResult, decodeResult: nil)
		}
		PerfTimer.trackEnd(name: "Deck Search", start: searchStart)

		// =-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-
		// Decode and process the deck
		// =-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-

		let decodeStart = PerfTimer.trackBegin()
		let decodeResult = Decoder.decode(debugBuffer: debugBuffer, markLines: markLines!, deckFormat: codeDefinition.format)

		var result: AnalysisResult?
		switch decodeResult
		{
			case .GeneralFailure(let reason):
				gLogger.error("Decode General Failure: \(reason)")
				resultStats.decodeGeneralFailureCount += 1
				result = .Fail(deckSearchResult: deckSearchResult, decodeResult: decodeResult)
			case .NotSharp:
				resultStats.decodeBlurryCount += 1
				result = .Fail(deckSearchResult: deckSearchResult, decodeResult: decodeResult)
			case .TooFewCards:
				resultStats.decodeTooFewCardsCount += 1
				result = .Fail(deckSearchResult: deckSearchResult, decodeResult: decodeResult)
			case .Decoded:
				resultStats.decodeDecodedCount += 1
				if let deck = decodeResult.deck
				{
					result = deck.analyze(deckSearchResult: deckSearchResult, decodeResult: decodeResult)

					switch result!
					{
						case .Inconclusive:
							resultStats.analyzedInconclusiveCount += 1
						case .InsufficientHistory:
							resultStats.analyzedInsufficientHistoryCount += 1
						case .InsufficientConfidence:
							resultStats.analyzedInsufficientConfidenceCount += 1
						case .SuccessLowConfidence:
							resultStats.analyzedReportLowConfidenceCount += 1
						case .SuccessHighConfidence:
							resultStats.analyzedReportHighConfidenceCount += 1
						case .Fail:
							resultStats.analyzedFailureCount += 1
					}
				}
				else
				{
					gLogger.error("Decode General Failure: We are decoded, but have no result")
					resultStats.analyzedFailureCount += 1
					result = .Fail(deckSearchResult: deckSearchResult, decodeResult: decodeResult)
				}
		}
		PerfTimer.trackEnd(name: "Deck Decode", start: decodeStart)

		return result!
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Reset the full set of scanning statistics
	///
	/// This includes the search and decoding statistics as well as the validation results
	public func reset()
	{
		resultStats.reset()

		PerfTimer.reset()
		PerfTimer.start()

		History.instance.reset()
	}
}
