//
//  DeckSearch.swift
//  Seer
//
//  Created by Paul Nettle on 11/10/16.
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

/// Class consisting mostly of class methods which search images for a deck
public final class DeckSearch
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Custom types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Stores temporal state information, used to keep track of where previous decks were found. This allows future searches to
	/// start from the same location/angle in order to reduce time to find decks in future time-consecutive images.
	public struct TemporalState
	{
		/// Offset of the search line where the previous deck was found
		public let offset: IVector

		/// Angle of the search line where the previous deck was found
		public let angleDegrees: Real

		/// Compiler bug: Inserting this entry into the struct avoids a compiler crash in the 3.0.2 compiler (Apple)
		public let __COMPILER_FIX__: String = ""

		/// When this temporal state was valid
		public let validTimeMS: Time

		/// Initialize a temporal state
		public init()
		{
			self.offset = IVector()
			self.angleDegrees = 0
			self.validTimeMS = 0
		}

		/// Initialize a temporal state from the essentials
		public init(offset: IVector, angleDegrees: Real)
		{
			self.offset = offset
			self.angleDegrees = angleDegrees
			self.validTimeMS = PausableTime.getTimeMS()
		}

		/// Temporal states are only good for a period of time (hence the use of the term temporal)
		public func hasExpired() -> Bool
		{
			return validTimeMS == 0 || PausableTime.getTimeMS() - validTimeMS > Config.searchTemporalExpirationMS
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The rate at which the sequential grid is displayed. This value represents the number of MS between grid lines being
	/// displayed in sequence
	private let kSequentialGridLinesRateMS: Int = 20

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Our current temporal state, useful for tracking the deck through the video
	private var temporalState = TemporalState()

	/// The pre-calculated search lines used to scan the image. These search lines will be relative the center
	/// of the screen, plus any TemporalState values
	private var markLines: MarkLines

	/// The pre-calculated search lines used to scan the image. These search lines will be relative the center
	/// of the screen, plus any TemporalState values
	private var searchLines: SearchLines

	/// We'll re-use this sample line while tracing marks
	private var traceMarksSampleLine = SampleLine()

	/// We use a static EdgeDetection to avoid having to allocate a new one for each search line
	private let edgeDetector = EdgeDetection(predictedSize: 2048)

	/// Left side center marks
	///
	/// Note that values toward the top of the deck are pushed FRONT and values toward the bottom of the deck are pushed BACK
	private var lCenterMarks = UnsafeBidirectionalArray<IVector>(withCapacity: Deck.kMaxSampleHeight)

	/// Right side center marks
	///
	/// Note that values toward the top of the deck are pushed FRONT and values toward the bottom of the deck are pushed BACK
	private var rCenterMarks = UnsafeBidirectionalArray<IVector>(withCapacity: Deck.kMaxSampleHeight)

	/// Local storage of the debug buffer
	private var debugBuffer: DebugBuffer?

	/// Local storage of the luma buffer
	///
	/// Note that we allocate a 1x1 LumaBuffer to avoid making it an optional
	private var lumaBuffer = LumaBuffer(width: 1, height: 1)

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	public init(size: IVector)
	{
		searchLines = SearchLines(size: size)
		markLines = MarkLines()
	}

	deinit
	{
		lCenterMarks.free()
		rCenterMarks.free()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Scan an image for deck LandMarks and return a set of MarkLines that represent the marks
	///
	/// - Parameter lumaBuffer: Buffer of luminance sample values to scan
	/// - Parameter debugBuffer: Buffer used to draw debug information
	public func scanImage(debugBuffer inDebugBuffer: DebugBuffer?, lumaBuffer inLumaBuffer: LumaBuffer, codeDefinition: CodeDefinition) -> SearchResult
	{
		// Do we need to update the search lines?
		if searchLines.isOutdated(size: IVector(x: inLumaBuffer.width, y: inLumaBuffer.height), reversible: codeDefinition.format.reversible)
		{
			searchLines = SearchLines(size: IVector(x: inLumaBuffer.width, y: inLumaBuffer.height), reversible: codeDefinition.format.reversible)
		}

		// Set these up so we can avoid passing them around
		debugBuffer = inDebugBuffer
		lumaBuffer = inLumaBuffer

		if Config.debugDrawSequentialSearchLineOrder
		{
			debugDrawSequentialSearchLineOrder(image: debugBuffer)
		}

		// If we are replaying a temporal state, override the temporal state with the replay state
		if Config.isReplayingFrame
		{
			temporalState = Config.replayTemporalState
		}
		// We're not replaying, so store this state off so we can replay next time if we need to
		else
		{
			// If our temporal state has expired, reset it so we can start anew
			if temporalState.hasExpired()
			{
				resetTemporalState()
			}

			Config.replayTemporalState = temporalState
		}

		// Grab our current temporal state values and reset the stored state so we can populate it with any newly found deck
		let temporalOffset = temporalState.offset
		let temporalAngle = temporalState.angleDegrees

		let origin = lumaBuffer.rect.center.chopToPoint()

		if Config.debugDrawFullSearchGrid
		{
			debugDrawFullSearchGrid(image: debugBuffer, origin: origin, offsetLocation: temporalOffset, offsetAngleDegrees: temporalAngle)
		}

		let edgeDetectionWindowSize = Int(codeDefinition.narrowestLandmarkNormalizedWidth() * codeDefinition.calcMinSampleWidth())
		let edgeDetectionminMaxWindowSize = Int(Config.searchEdgeDetectionDeckRollingMinMaxWindowMultiplier * Real(edgeDetectionWindowSize))

		for i in 0..<searchLines.count
		{
			//
			// Scan for the deck
			//

			// Get a search line
			guard let searchLine = searchLines[i].getLine(origin: origin, offsetLocation: temporalOffset, offsetAngleDegrees: temporalAngle, bufferRect: lumaBuffer.rect) else
			{
				continue
			}

			// Scan the search line for a deck's landmarks
			guard let match = matchSearchLine(codeDefinition: codeDefinition, sampleLine: searchLine, imageHeight: lumaBuffer.height, windowSize: edgeDetectionWindowSize, minMaxWindowSize: edgeDetectionminMaxWindowSize) else
			{
				continue
			}

			// Log some match info
			if Config.debugDrawDeckMatchResults
			{
				match.debugDrawOverlay(image: debugBuffer, codeDefinition: codeDefinition)
			}

			if Config.debugDrawMatchedDeckLocations
			{
				match.deckLocation.debugDrawOverlay(image: debugBuffer)
			}

			//
			// Temporal tracking (low accuracy)
			//

			let matchLine = match.deckLocation.sampleLine
			let matchLineVector = matchLine.toLine().vector
			let matchLineNormal = matchLineVector.normal()
			if !Config.isReplayingFrame
			{
				let angleDegrees = matchLineNormal.angleDegrees(to: Vector(x: 1, y: 0))
				temporalState = TemporalState(offset: matchLine.center - origin, angleDegrees: angleDegrees)
			}

			//
			// Is the deck wide enough?
			//

			// Is the deck large enough to scan?
			let minSampleWidth = codeDefinition.calcMinSampleWidth(withDeckAngleNormal: matchLineNormal)
			if matchLineVector.length < minSampleWidth
			{
				if Config.debugDrawMatchedDeckLocationDiscards
				{
					match.deckLocation.debugDrawOverlay(image: debugBuffer, color: kDebugDeckLocationRangeColorBadWidth)
				}
				return .TooSmall
			}

			//
			// Find the deck extents
			//

			if !findDeckExtents(codeDefinition: codeDefinition, match: match, imageHeight: lumaBuffer.height) { continue }
			if lCenterMarks.count < 2 { continue }
			if rCenterMarks.count < 2 { continue }

			var lTop: IVector
			var lBot: IVector
			var rTop: IVector
			var rBot: IVector

			if Config.searchUseLandmarkContours
			{
				let lPoints = lCenterMarks.interpolatedData;	lTop = lPoints[0];	lBot = lPoints[lPoints.count - 1]
				let rPoints = rCenterMarks.interpolatedData;	rTop = rPoints[0];	rBot = rPoints[rPoints.count - 1]
			}
			else
			{
				lTop = lCenterMarks.front!;	rTop = rCenterMarks.front!
				lBot = lCenterMarks.back!;	rBot = rCenterMarks.back!
			}

			//
			// Temporal tracking (high accuracy)
			//

			// Note that we generate a center point that is the actual center based on our extents
			let deckCenterLeft = (lTop + lBot) / 2
			let deckCenterRight = (rTop + rBot) / 2
			let centerVector = (deckCenterRight - deckCenterLeft).toVector().normal()
			if !Config.isReplayingFrame
			{
				let deckCenter = (deckCenterLeft + deckCenterRight) / 2
				let angleDegrees = centerVector.angleDegrees(to: Vector(x: 1, y: 0))
				temporalState = TemporalState(offset: deckCenter - origin, angleDegrees: angleDegrees)
			}

			//
			// Is the deck tall enough?
			//

			let deckHeight = Real(min(lTop.distance(to: lBot), rTop.distance(to: rBot)))
			let minHeight = codeDefinition.calcMinSampleHeight(withDeckAngleNormal: centerVector, forCardCount: codeDefinition.format.minCardCount)
			if deckHeight < minHeight
			{
				if Config.debugDrawMatchedDeckLocationDiscards
				{
					match.deckLocation.debugDrawOverlay(image: debugBuffer, color: kDebugDeckLocationRangeColorBadWidth)
				}
				return .TooSmall
			}

			//
			// Find mark lines
			//

			// Note that we optionally select between linear/contoured MarkLines
			if Config.searchUseLandmarkContours ?
				markLines.generateContouredMarkLines(debugBuffer: debugBuffer, lumaBuffer: lumaBuffer, codeDefinition: codeDefinition, match: match, leftCenters: lCenterMarks, rightCenters: rCenterMarks)
				:
				markLines.generateLinearMarkLines(debugBuffer: debugBuffer, lumaBuffer: lumaBuffer, codeDefinition: codeDefinition, match: match, topLine: SampleLine(p0: lTop, p1: rTop), bottomLine: SampleLine(p0: lBot, p1: rBot))
			{
				// Whew! We found the bits in the deck!
				return .Decodable(markLines: markLines)
			}
		}

		return .NotFound
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Deck matching
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Scan the samples along a given line and return a DeckMatchResult if a valid deck was found.
	///
	/// Note that the `windowSize` parameter is used for edge detection rolling averages
	private func matchSearchLine(codeDefinition: CodeDefinition, sampleLine: SampleLine, imageHeight: Int, windowSize: Int, minMaxWindowSize: Int) -> DeckMatchResult?
	{
		// Draw the search line so we can track where we've been
		if Config.debugDrawSearchedLines
		{
			sampleLine.draw(to: debugBuffer, color: kDebugSearchLineColor)
		}

		if !sampleLine.sample(from: lumaBuffer, invertSampleLuma: codeDefinition.format.invertLuma) { return nil }

		guard let edges = edgeDetector.detectEdges(debugBuffer: debugBuffer,
		                                           sampleLine: sampleLine,
		                                           windowSize: windowSize,
		                                           minMaxWindowSize: minMaxWindowSize,
		                                           overlap: Config.searchEdgeDetectionDeckPeakRollingAverageOverlap,
		                                           sensitivity: Config.searchEdgeDetectionDeckEdgeSensitivity,
		                                           imageHeight: imageHeight) else
		{
			return nil
		}

		guard let markLocations = findMarks(edges: edges) else { return nil }

		if Config.debugDrawAllMarks
		{
			for markLocation in markLocations
			{
				markLocation.debugDrawOverlay(image: debugBuffer, color: kDebugUnusedMarkLocationLineColor)
			}
		}

		// Try to match in each direction
		return codeDefinition.bestMatch(markLocations: markLocations)
	}

	/// Scan a range of samples in the given sampleLine and return an optional set of MarkLocations if any are found.
	///
	/// Implementation details:
	///
	/// This function makes heavy use of the EdgeDetection.detectEdges functionality. This edge detection process tracks the slope
	/// of each edge detected, which allows us to know if the pixel has crossed into a dark region (the start of a mark) or into a
	/// light region (the end of a mark.)
	///
	/// Using this slope information, we are able to ignore certain edges (for example, two consecutive start edges.) In this way
	/// we are able to generate a set of MarkLocations that represent true mark-like data events along the SampleLine.
	///
	/// Note that edge detection requires a lead-in and lead-out data. Therefore, edges will not happen near the endpoints of
	/// `sampleLine`. The exact number of samples that are skipped at the start and at the end of `sampleLine` can be calculated
	/// with:
	///
	///     max(rolling_average_window_size, rolling_min_max_len) / 2
	private func findMarks(edges: [Edge]) -> [MarkLocation]?
	{
		// No edges found, stop here
		if edges.isEmpty { return nil }

		// Scan the sample edges to build a set of MarkLocations
		var markLocations = [MarkLocation]()
		markLocations.reserveCapacity(edges.count)
		var startEdge: Edge?
		for edge in edges
		{
			// Start a mark if the slope dropped below our threshold (it is dark; the start of a mark)
			if edge.slope < 0
			{
				startEdge = edge
			}
			// End a mark if the slope raised above our threshold (it is light; the end of a mark)
			else if startEdge != nil && edge.slope > 0
			{
				// Store the new mark location
				markLocations.append(MarkLocation(start: startEdge!, end: edge, scanIndex: markLocations.count))

				// Reset the current start
				startEdge = nil
			}
		}

		return markLocations.count == 0 ? nil : markLocations
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	//									 ____            _      _____      _             _
	//									|  _ \  ___  ___| | __ | ____|_  _| |_ ___ _ __ | |_ ___
	//									| | | |/ _ \/ __| |/ / |  _| \ \/ / __/ _ \ '_ \| __/ __|
	//									| |_| |  __/ (__|   <  | |___ >  <| ||  __/ | | | |_\__ \
	//									|____/ \___|\___|_|\_\ |_____/_/\_\\__\___|_| |_|\__|___/
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns a pair of SampleLines that represent the top and bottom edges of the deck
	///
	/// The deck extents are found by locating the LandMarks which border the BitMarks in the DeckMatchResult and tracing those
	/// marks in each direction (toward the top and bottom of the deck.)
	///
	/// Important implementation details:
	///
	/// Before reading this, be sure to familiarize yourself with the details of the `traceMark()` method.
	///
	/// It is important to note that the sample lines that trace the marks are oriented with the search line that found the deck.
	/// This can be problematic as this search may cut diagonally through the deck. To that end, we run perform the process in
	/// two phases: First, a rough iteration using a step value of '2' for `traceMark`. We then follow that up with a second pass
	/// using a step value of '1'.
	///
	/// In order to maximize accuracy, prior to running the second pass we perform an adjustment to the scan direction based on the
	/// results of the first pass. As the deck may be viewed with perspective, the top and bottom edges of the deck may not be
	/// parallel. Therefore, we adjust the scan directions for the top and bottom edges separately in order to provide scan
	/// directions that are aligned to each extent.
	private func findDeckExtents(codeDefinition: CodeDefinition, match: DeckMatchResult, imageHeight: Int) -> Bool
	{
		let _track_ = PerfTimer.ScopedTrack(name: "Trace marks"); _track_.use()

		let scanVector = match.deckLocation.sampleLine.vector

		// Find the marks that need to be traced
		guard let lMarkDef = codeDefinition.bitNeighboringLandmarks.first else { return false }
		guard let lMarkLoc = match.deckLocation.findMarkLocation(forMatchDefinitionIndex: lMarkDef.index) else { return false }
		guard let rMarkDef = codeDefinition.bitNeighboringLandmarks.last else { return false }
		guard let rMarkLoc = match.deckLocation.findMarkLocation(forMatchDefinitionIndex: rMarkDef.index) else { return false }

		let lMarkRatio = codeDefinition.markDefinitions[lMarkDef.index].landmarkMinGapRatio
		let lMarkExtension = (FixedPoint(lMarkLoc.sampleCount) * lMarkRatio).ceil()
		assert(lMarkExtension != 0)
		if lMarkExtension == 0 { return false }

		let rMarkRatio = codeDefinition.markDefinitions[rMarkDef.index].landmarkMinGapRatio
		let rMarkExtension = (FixedPoint(rMarkLoc.sampleCount) * rMarkRatio).ceil()
		assert(rMarkExtension != 0)
		if rMarkExtension == 0 { return false }

		// Coarse trace (every other sample)
		var step = 2

		//
		// Initial (coarse) trace of the left-side marks
		//
		lCenterMarks.removeAll()
		lCenterMarks.pushFront(lMarkLoc.center)

		// When tracing edges to find the deck extents, we'll allow a few misses to ensure that we are able to capture the
		// full deck extent.
		//
		// This is a calculated property and is scaled from a base of 720p to the current input resolution
		let maxEdgeTraceMisses = Config.searchBaseMaxEdgeTraceMisses * imageHeight / 720

		let invertSampleLuma = codeDefinition.format.invertLuma

		traceMark(scanVector: scanVector, invertSampleLuma: invertSampleLuma, markWidth: lMarkLoc.sampleCount, markWidthExtension: lMarkExtension, center: lMarkLoc.center, step: step, towardTop: true, centerMarks: &lCenterMarks, maxEdgeTraceMisses: maxEdgeTraceMisses)
		traceMark(scanVector: scanVector, invertSampleLuma: invertSampleLuma, markWidth: lMarkLoc.sampleCount, markWidthExtension: lMarkExtension, center: lMarkLoc.center, step: step, towardTop: false, centerMarks: &lCenterMarks, maxEdgeTraceMisses: maxEdgeTraceMisses)

		// Grab the first pass extents
		guard let lTopAlignCenter = lCenterMarks.front else { return false }
		guard let lBotAlignCenter = lCenterMarks.back else { return false }

		// Back up a bit
		guard let lTopNewCenter = lCenterMarks.popFront(count: Config.searchTraceMarkBackupDistance) else { return false }
		guard let lBotNewCenter = lCenterMarks.popBack(count: Config.searchTraceMarkBackupDistance) else { return false }

		//
		// Initial (coarse) trace of the right-side marks
		//
		rCenterMarks.removeAll()
		rCenterMarks.pushFront(rMarkLoc.center)
		traceMark(scanVector: scanVector, invertSampleLuma: invertSampleLuma, markWidth: rMarkLoc.sampleCount, markWidthExtension: rMarkExtension, center: rMarkLoc.center, step: step, towardTop: true, centerMarks: &rCenterMarks, maxEdgeTraceMisses: maxEdgeTraceMisses)
		traceMark(scanVector: scanVector, invertSampleLuma: invertSampleLuma, markWidth: rMarkLoc.sampleCount, markWidthExtension: rMarkExtension, center: rMarkLoc.center, step: step, towardTop: false, centerMarks: &rCenterMarks, maxEdgeTraceMisses: maxEdgeTraceMisses)

		// Grab the first pass extents
		guard let rTopAlignCenter = rCenterMarks.front else { return false }
		guard let rBotAlignCenter = rCenterMarks.back else { return false }

		// Back up a bit
		guard let rTopNewCenter = rCenterMarks.popFront(count: Config.searchTraceMarkBackupDistance) else { return false }
		guard let rBotNewCenter = rCenterMarks.popBack(count: Config.searchTraceMarkBackupDistance) else { return false }

		//
		// Re-align to the top and bottom edges of the deck so we can perform a fine trace
		//
		let topScanVector = rTopAlignCenter - lTopAlignCenter
		let botScanVector = rBotAlignCenter - lBotAlignCenter

		// Fine trace - every sample
		step = 1

		//
		// Final (fine, aligned) trace of the left-side marks
		//
		traceMark(scanVector: topScanVector, invertSampleLuma: invertSampleLuma, markWidth: lMarkLoc.sampleCount, markWidthExtension: lMarkExtension, center: lTopNewCenter, step: step, towardTop: true, centerMarks: &lCenterMarks, maxEdgeTraceMisses: maxEdgeTraceMisses)
		traceMark(scanVector: botScanVector, invertSampleLuma: invertSampleLuma, markWidth: lMarkLoc.sampleCount, markWidthExtension: lMarkExtension, center: lBotNewCenter, step: step, towardTop: false, centerMarks: &lCenterMarks, maxEdgeTraceMisses: maxEdgeTraceMisses)

		//
		// Final (fine, aligned) trace of the right-side marks
		//
		traceMark(scanVector: topScanVector, invertSampleLuma: invertSampleLuma, markWidth: rMarkLoc.sampleCount, markWidthExtension: rMarkExtension, center: rTopNewCenter, step: step, towardTop: true, centerMarks: &rCenterMarks, maxEdgeTraceMisses: maxEdgeTraceMisses)
		traceMark(scanVector: botScanVector, invertSampleLuma: invertSampleLuma, markWidth: rMarkLoc.sampleCount, markWidthExtension: rMarkExtension, center: rBotNewCenter, step: step, towardTop: false, centerMarks: &rCenterMarks, maxEdgeTraceMisses: maxEdgeTraceMisses)

		if Config.debugDrawDeckExtents
		{
			debugDrawDeckExtents(interpolatedContours: false)
		}

		if Config.searchUseLandmarkContours
		{
			// Get the interpolation direction mask (perpendicular to our scan vector)
			let interpMask = scanVector.orthoNormalMask.swappedComponents()

			// Our final deck extents, interpolated and filtered
			_ = lCenterMarks.interpolateGaps(withMask: interpMask)
			_ = rCenterMarks.interpolateGaps(withMask: interpMask)
		}

		if Config.debugDrawDeckExtents
		{
			debugDrawDeckExtents()
		}

		return true
	}

	/// Traces a LandMark in a given direction in an effort to locate one of the vertical extents of a deck
	///
	/// HIGH LEVEL DESCRIPTION
	///
	/// The process of tracing a LandMark involves iteratively performing Landmark detection to locate the mark's center then
	/// stepping to the next position along the vertical direction of the deck and repeating. The process ends when the LandMark
	/// can no longer be found, indicating the edge of the deck.
	///
	/// IMPLEMENTATION DETAILS
	///
	/// One of the primary purposes of this routine is to trace LandMarks for decks that are not perfectly stacked. This means that
	/// LandMark positions will shift relative to the deck as the LandMark is traced up or down the deck. To that end, each time a
	/// LandMark is found, it is re-centered on the newly found LandMark to reflect its updated (shifted) center.
	///
	/// In order to locate the LandMark, we require a localized SampleLine. This SampleLine is oriented to the given `scanVector`,
	/// centered on the LandMark and given a length relative to `markWidth`. The LandMark's position starts at `center` and is
	/// continuously adjusted with the LandMark as it may shift from side to side as we traverse along the deck's vertical
	/// dimension. In addition, the length of the SampleLine is calculated beginning with `markWidth` and lengthened to account for
	/// possible shifts in Landmark positioning. For more information, see the section below, regarding the `markWidthExtension`
	/// parameter.
	///
	/// Landmark detection consists of two simple principles. The first is the use of a rolling sum (an average is not needed) with
	/// a window size equal to or slightly larger than the Landmark (`markWidth`.) The center of the moving window for the smallest
	/// rolling sum value will be the sample at the center of the Landmark, since it will be surrounded by the most dark pixels from
	/// the Landmark. Being able to locate the center of the Landmark is half of the problem; we still need to determin when we are
	/// no longer on the Landmark. This is done by calculating the average of all samples on the sample line and comparing that
	/// against the average of the minimum rolling sum, scaled to the range of sample intensities. If that scalar is within a
	/// threshold, then we assume that we are on an actual Landmark.
	///
	/// The most critical component to this process is the use of the localized SampleLine that will drive Landmark detection. As
	/// SampleLines are comprised of integer coordinates, we must be careful in how we step their positions as we account for
	/// shifting LandMark positions and step along the deck's vertical dimension. In both cases we use orthogonal normals, which
	/// ensures that we step exactly a certain number of pixels in the desired direction (specified by `towardTop`.)
	///
	/// In addition to locating the deck extents, this method will also populate the `centerMarks` array with the centers of the
	/// LandMarks that were found, providing a guide to the shifting positions of the deck. As the deck is traced from the search
	/// line outward to the extents, the `centerMarks` array is built in a center-out fashion, growing outward from the center in
	/// order to provide a linear array of center points extending from the top of the deck to the bottom. To that end, it is up
	/// to the caller to provide a proper `centerMarksOffset` which begins at the center of the `centerMarks` array with different
	/// offsets used when scanning toward the top of the deck or bottom. Care should also be taken if this method is called
	/// iteratively (for course/fine grained scanning.) Note that indices into the `centerMarks` array denoting center positions
	/// toward the top of the deck will be negative of center of the array, while indices toward the bottom of the deck will be
	/// positive of center.
	///
	/// A NOTE ABOUT THE `markWidthExtension` PARAMETER
	///
	/// We use a subset of the mark's width for our extension length. This is calculated as half the distance of the shortest gap
	/// on either side of the landmark being traced. This is to avoid the case where tracing extends into other marks. In those
	/// cases, the tracing can pull the mark in their direction. Our solution is to calculate the amount of space on either side of
	/// the landmark being traced (based on its neighboring spaces) and only trace half the distance to to them (to provide a bit
	/// of a buffer.) This should solve the problem but will reduce our ability to stray horizontally.
	///
	/// A NOTE ABOUT ACCURACY
	///
	/// Aside from the standard accuracy limitations introduced by the use of EdgeDetection, this method will suffer additional
	/// accuracy reduction with a `scanVector` that deviates from being perfectly perpendicular to the LandMark. To that end, it
	/// makes sense to call this method once to get a rough 'guess' as to the deck's extents, adjust the `scanVector` to that of
	/// the estimated deck extents, then call this method again to get the most accurate extents. In doing this, one should also
	/// 'rewind' the results a bit (i.e., the second call should not start where the first call leaves off, but rather back up a
	/// bit first.)
	///
	/// A NOTE ABOUT PERFORMANCE
	///
	/// In order to improve performance the SampleLine used for edge detection is localized to the LandMark alone and is only wide
	/// enough to allow for moderate shifts in the LandMark's position.
	///
	/// Furthermore, the caller specifies a `step` value which determines how far to step along the deck's vertical extents. Be
	/// careful with this! A step value of 2 will perform half the work, but will be capable of detecting smaller shift amounts
	/// within the LandMark. This author does not recommend going above 2. In addition, be aware that with a step value > 1, the
	/// exact extent of the deck may not be returned (the actual termination point could land between steps.)
	private func traceMark(scanVector: IVector, invertSampleLuma: Bool, markWidth: Int, markWidthExtension: Int, center: IVector, step: Int, towardTop: Bool, centerMarks: inout UnsafeBidirectionalArray<IVector>, maxEdgeTraceMisses: Int)
	{
		// A half-vector that defines the vector for a cross-section of our landmark, perpendicular to its maximal extent.
		//
		// Note that the magnitude of this vector defines the distance from the center of this landmark out in either direction.
		// In other words, it is half of the total distance of the trace.
		let xHalfVector = (scanVector.normalized() * (markWidth / 2 + markWidthExtension)).denormalized()

		// The orthogonal normal of our X vector
		let xVectorNormal = xHalfVector.orthoNormalMask

		// The Y vector, which traverses the landmark along its maximal extent, with direction and step size applied
		let yVectorNormal = xVectorNormal.swappedComponents() * (towardTop ? -step : step)

		// A mark is allowed to stray (horizontally) this much
		let xStrayDistance = (markWidth.toFixed() * Config.searchTraceMarksMaxStray).floor()

		// Our initial mark center (also our initial last good center)
		var curCenter = center

		// We only allow a certain number of failures (to skip blurry or poorly marked marks) - this keeps track of our failures
		var failCount = 0

		var avgDeltaIntensitySum: Int64 = 0
		var avgDeltaIntensityCnt: Int = 0
		let searchTraceMarksEdgeSensitivity: Int64 = Int64(Config.searchTraceMarksEdgeSensitivity.value)
		let fixedShift: Int64 = Int64(FixedPoint.kFractionalBits)

		// Visit each mark location and trace up/down
		while true
		{
			// Step the mark to the next line
			curCenter += yVectorNormal

			// Sample the SampleLine. If this fails, we're probably past the edge of the screen, so bail
			if !traceMarksSampleLine.sample(from: lumaBuffer, invertSampleLuma: invertSampleLuma, p0: curCenter - xHalfVector, p1: curCenter + xHalfVector) { return }
			if traceMarksSampleLine.sampleCount <= (markWidth + markWidthExtension) { return }

			let samples = traceMarksSampleLine.samples

			//
			// Roll the segment to find the max
			//
			var segmentMax = 0
			do
			{
				// Sum the head segment of our samples
				for i in 0..<markWidthExtension { segmentMax += Int(samples[i]) }

				// Roll the sum
				var sum = segmentMax
				for i in markWidthExtension..<samples.count
				{
					sum -= Int(samples[i-markWidthExtension])
					sum += Int(samples[i])
					if sum > segmentMax { segmentMax = sum }
				}
			}

			//
			// Roll the mark to find the center/min
			//
			var centerMin = 0
			var centerIdx = markWidth
			do
			{
				// Sum the head of our samples
				for i in 0..<markWidth { centerMin += Int(samples[i]) }

				// Roll the sum
				var sum = centerMin
				for i in markWidth..<samples.count
				{
					sum -= Int(samples[i-markWidth])
					sum += Int(samples[i])
					if sum < centerMin { centerMin = sum; centerIdx = i }
				}

				// Adjust our center to the actual center
				centerIdx -= markWidth / 2
			}

			// We keep an average of the min/max delta which we use to determine when we leave the deck
			let thisDelta = segmentMax / markWidthExtension - centerMin / markWidth
			avgDeltaIntensitySum += Int64(thisDelta)
			avgDeltaIntensityCnt += 1

			// The ratio of this mark's intensity delta must be within a tolerance to the average we've had so far
			//
			// NOTE: We need to scale by a fixed point value, but the result may be too large for a fixed, so we do some
			// manual fixed point work here.
			let minDelta = Int((searchTraceMarksEdgeSensitivity * avgDeltaIntensitySum) >> fixedShift) / avgDeltaIntensityCnt

			// Did we find a real mark?
			//
			// We first ensure the mark's intensity delta is within tolerance. Next, we verify that the mark hasn't strayed too far
			// from the originating mark.
			if thisDelta > minDelta &&
			   ((center - curCenter) * xVectorNormal).length.floor() <= xStrayDistance
			{
				if Config.debugDrawTraceMarks
				{
					curCenter.draw(to: debugBuffer, color: 0xffffffff)
					traceMarksSampleLine.draw(to: debugBuffer, color: kDebugSearchDeckExtentsLandmarkSampleLineColor)
				}

				// Add it to the array
				if towardTop { centerMarks.pushFront(curCenter) }
				else         { centerMarks.pushBack(curCenter) }

				failCount = 0

				// Find the center of the new mark on the line
				let v = traceMarksSampleLine.vector * centerIdx / (samples.count-1)
				let newCenter = traceMarksSampleLine.p0 + v

				// Adjust our center to follow the contour of the mark
				curCenter += (newCenter - curCenter) * xVectorNormal

				if centerMarks.count >= centerMarks.capacity { return }
			}
			else
			{
				if Config.debugDrawTraceMarks
				{
					if thisDelta > minDelta
					{
						traceMarksSampleLine.draw(to: debugBuffer, color: 0x80a0a000)
					}
					else
					{
						traceMarksSampleLine.draw(to: debugBuffer, color: 0x40800000)
					}
				}

				// Track the number of failures and bail when we have too many
				failCount += step
				if failCount >= maxEdgeTraceMisses { break }

				// Don't let the failed line impact our intensity sum
				avgDeltaIntensitySum -= Int64(thisDelta)
				avgDeltaIntensityCnt -= 1
			}
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Resets the current temporal state to 'no state'
	///
	/// Call this method when the next image to be searched will not be temporally coherent to the previous.
	private func resetTemporalState()
	{
		temporalState = TemporalState()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Debug
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Draws the deck extents: A line at the top/bottom of the deck along with the bit-neighboring LandMark centers
	///
	/// This method will appropriately draw the deck extents using the raw LandMark centers data, or the interpolated data (used by
	/// the LandMark contours.)
	private func debugDrawDeckExtents(interpolatedContours: Bool = true)
	{
		if Config.searchUseLandmarkContours
		{
			let lInterp = interpolatedContours ? lCenterMarks.interpolatedData : lCenterMarks.data
			let rInterp = interpolatedContours ? rCenterMarks.interpolatedData : rCenterMarks.data
			let lStart = interpolatedContours ? 0 : lCenterMarks.frontIndex
			let rStart = interpolatedContours ? 0 : rCenterMarks.frontIndex
			let lCount = interpolatedContours ? lInterp.count : lCenterMarks.count
			let rCount = interpolatedContours ? rInterp.count : rCenterMarks.count
			let left = SampleLine(p0: lInterp[lStart], p1: lInterp[lStart + lCount-1])
			let right = SampleLine(p0: rInterp[rStart], p1: rInterp[rStart + rCount-1])
			let topLine = SampleLine(p0: left.p0, p1: right.p0)
			let bottomLine = SampleLine(p0: left.p1, p1: right.p1)
			topLine.draw(to: debugBuffer, color: kDebugDeckExtentsDeckLineColor)
			bottomLine.draw(to: debugBuffer, color: kDebugDeckExtentsDeckLineColor)
			let color: Color = interpolatedContours ? 0xff80ffff : 0xffffffff

			for i in 0..<lCount
			{
				lInterp[i+lStart].draw(to: debugBuffer, color: color)
			}
			for i in 0..<rCount
			{
				rInterp[i+rStart].draw(to: debugBuffer, color: color)
			}
		}
		else
		{
			let left = SampleLine(p0: lCenterMarks.front!, p1: lCenterMarks.back!)
			let right = SampleLine(p0: rCenterMarks.front!, p1: rCenterMarks.back!)
			let topLine = SampleLine(p0: left.p0, p1: right.p0)
			let bottomLine = SampleLine(p0: left.p1, p1: right.p1)
			topLine.draw(to: debugBuffer, color: kDebugDeckExtentsDeckLineColor)
			bottomLine.draw(to: debugBuffer, color: kDebugDeckExtentsDeckLineColor)
			left.draw(to: debugBuffer, color: kDebugDeckExtentsDeckLineColor)
			right.draw(to: debugBuffer, color: kDebugDeckExtentsDeckLineColor)
		}
	}

	private func debugDrawSequentialSearchLineOrder(image: DebugBuffer?)
	{
		guard let width = image?.width else { return }
		guard let height = image?.height else { return }
		guard let rect = image?.rect else { return }

		let origin = IVector(x: width/2, y: height/2)
		let frameID = Int(PausableTime.getTimeMS().truncatingRemainder(dividingBy: Time(searchLines.count * kSequentialGridLinesRateMS)) / Time(kSequentialGridLinesRateMS))

		for i in 0..<frameID
		{
			let searchLine = searchLines[i]
			if let line = searchLine.getLine(origin: origin, offsetLocation: IVector(), offsetAngleDegrees: 0, bufferRect: rect)
			{
				line.draw(to: image, color: kDebugSequentialSearchLineColor)
			}
		}
	}

	private func debugDrawFullSearchGrid(image: DebugBuffer?, origin: IVector, offsetLocation: IVector, offsetAngleDegrees: Real)
	{
		if let image = image
		{
			for i in 0..<searchLines.count
			{
				if let line = searchLines[i].getLine(origin: origin, offsetLocation: offsetLocation, offsetAngleDegrees: offsetAngleDegrees, bufferRect: image.rect)
				{
					line.draw(to: image, color: kDebugSearchGridLineColor)
				}
			}
		}
	}
}
