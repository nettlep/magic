//
//  EdgeDetection.swift
//  Seer
//
//  Created by Paul Nettle on 12/17/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// The EdgeDetection is intended to operate on linear data for common edge-detection values, such as rolling averages, rolling
/// sums, rolling slopes, etc.
///
/// When possible, be sure to re-use instances of EdgeDetection objects. EdgeDetection includes a strategy for reallocation that
/// reduces the number of allocations needed over time. By not reusing instances of EdgeDetection objects, you will incur a
/// performance penalty for unnecessary allocations.
///
/// Important implementation detail:
///
/// In order to increase performance, rather than using a rolling average, we use a rolling sum. Remember that a rolling average is
/// calculated using the same process as a rolling sum, with the additional step of dividing each sum by the size of the window.
/// A rolling sum is effectively a rolling average that is scaled by its own window size. This has an added benefit of preserving
/// full precision on the rolled values while still storing them as standard integers.
///
/// As it turns out, this edge detection method works naturally with scaled values throughout with only one notable runtime
/// exception: the limiting of the dynamically calculated threshold with `kMinimumThreshold`. There is also a non-notable exception
/// in that the debug visualizers need to scale down the data in order to display it properly.
final class EdgeDetection
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Internal data
	///
	/// The contents of this array will vary depending on the operation that has been run. For general edge detection, this will
	/// hold the rolling sum values. However, it may hold any other type of data if the object is initialized with `sourceData`
	/// or another EdgeDetection object. It may also contain something completely different, if being used for debugging purposes.
	private var data: UnsafeMutableArray<RollValue>

	/// The detected edges
	private var edgesDetected = [Edge]()

	/// Internal storage of peaks as they are detected, but prior to being converted to Edges
	private static var rolledPeaks = UnsafeMutableArray<Peak>()

	/// Internal storage of rolling min/max values used during edge detection
	private static var rolledMinMax = UnsafeMutableArray<MinMax<Sample>>()

	#if DEBUG
	/// Used to track the sequence of debuggable edges in order to determine which edge detection is drawn when Config.debugDrawEdges
	/// is enabled
	private static var debuggableEdgeDetectionSequenceId = 0
	#endif

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initializes a EdgeDetection object with a prediction of the number of samples that will be used as input
	///
	/// The data will be pre-initialized to the given `predictedSize` and will grow as needed.
	init(predictedSize: Int)
	{
		self.data = UnsafeMutableArray<RollValue>(withCapacity: predictedSize)
	}

	/// Copies a EdgeDetection object, duplicating the internal data
	init(_ rhs: EdgeDetection)
	{
		self.data = UnsafeMutableArray<RollValue>(rhs.data)
	}

	/// Cleanup any allocated memory used by this object
	deinit
	{
		data.free()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Edge detection
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Performs edge detection on a SampleLine, returning an array of Edge objects for those edges found, or nil on error.
	///
	/// This is the public-facing interface routine for edge detection. For further details on the edge detection process, see the
	/// `findPeaks` and `thresholdPeaks` methods.
	///
	/// It is assumed that the caller has already sampled the line (or populated the SampleLine with appropriate data in some way.)
	///
	/// At the end of this call, `data` will contain rolling sums. After calling this method, `peakValues` and `peakIndices`
	/// will contain the peak data.
	///
	/// The `windowSize` parameter is used for the rolling sums (see `UnsafeMutableArray.rollSums` for more information.)
	///
	/// The `minMaxWindowSize` parameter is used for the rolling min/max values, which are an important component into the dynamic
	/// threshold calculations (see `thresholdPeaks` for more information.) For general frame edge detection, this should generally
	/// be larger at least 2x the `windowSize` as it should reference the general area around the edge and should be large enough
	/// to ensure that it includes data around the feature to detect in order to provide a good sense of the intensity range for
	/// the area around the edge. For detecting edges in smaller, localized areas, a rolling min/max may not provide much value
	/// compared to the cost of it. In these cases, `minMaxWindowSize` can be set to 0, causing a single min/max value to be
	/// calculated for the full SampleLine, providing better performance.
	///
	/// The `overlap` specifies how much to overlap the rolling sum windows when searching for peaks. For further details, see
	/// the `rollingSlopeOverlap` parameter to `findPeaks`. Note, however, that `rollingSlopeOverlap` is actually calculated from
	/// (`windowSize` - `overlap`).
	///
	/// The `sensitivity` is a unit scalar used to specify edge detection sensitivity (higher sensitivity values will find more
	/// edges.) See `findPeaks` for more information.
	///
	/// Actual edge detection is performed by applying a threshold to the peak values, keeping only those peaks that meet or exceed
	/// a threshold. The threshold is calculated at two levels. If `minMaxWindowSize` is 0, then a single threshold is calculated
	/// and used for the entire SampleLine. Otherwise, dynamic thresholding is used. These operations are performed by the two
	/// different `thresholdPeaks` methods. For details on the threshold calculation itself, see `calcThreshold`.
	///
	/// ** IMPORTANT NOTE ABOUT WINDOW SIZE SCALE **
	///
	/// The two window sizes (`windowSize` and `minMaxWindowSize`) should be scaled the size of a 720p video. This method will
	/// automatically adjust each so that they are properly scaled to the input resolution.
	///
	/// In the case of an error, this method will return nil. Examples of errors are:
	///
	///   * If there is not enough data to roll sums or roll min/max values
	///   * If there is not enough data to find peaks
	///
	/// If no error occurs but no edges can be found, this method will return an empty array of Edges.
	func detectEdges(debugBuffer: DebugBuffer?, sampleLine: SampleLine, windowSize inWindowSize: Int, minMaxWindowSize inMinMaxWindowSize: Int, overlap: Int, sensitivity: FixedPoint, imageHeight: Int) -> [Edge]?
	{
		// Reset the set of detected edges
		edgesDetected.removeAll(keepingCapacity: true)

		// Track our sequence ID
		#if DEBUG
		let debugSequenceId = EdgeDetection.debuggableEdgeDetectionSequenceId
		EdgeDetection.debuggableEdgeDetectionSequenceId += 1
		#endif

		// Scale our window sizes to suit the resolution of the image
		//
		// IMPORTANT: See the section 'Important implementation detail' in the class description for details how this value is used
		//            to maintain the relative scale of our data.
		let windowSize = inWindowSize * imageHeight / 720
		let minMaxWindowSize = inMinMaxWindowSize * imageHeight / 720

		// Roll the sums
		if !data.rollSums(samples: sampleLine.samples, windowSize: windowSize) { return nil }

		// Find the peaks
		let peakOffset = windowSize - 1 - overlap/2
		let rollingSlopeOffset = windowSize-overlap
		if !findPeaks(rollingSlopeOffset: rollingSlopeOffset) { return nil }

		// Threshold the peaks to produce a final set of peaks which represent actual edges
		//
		// Note that we can do this either with rolling the min/max or with a single min/max
		if minMaxWindowSize > 0
		{
			if !EdgeDetection.rolledMinMax.rollMinMax(samples: sampleLine.samples, count: data.count, windowSize: minMaxWindowSize) { return nil }
			thresholdPeaks(minMaxWindowSize: minMaxWindowSize, peakOffset: peakOffset, sensitivity: sensitivity, dataScale: RollValue(windowSize))
		}
		else
		{
			thresholdPeaks(minMax: sampleLine.samples.getMinMax(), peakOffset: peakOffset, sensitivity: sensitivity, dataScale: RollValue(windowSize))
		}

		// Generate the edges
		for i in 0..<EdgeDetection.rolledPeaks.count
		{
			let peak = EdgeDetection.rolledPeaks[i]
			edgesDetected.append(Edge(slope: peak.scaledPeakSlope, sampleOffset: peak.sampleOffset, threshold: peak.threshold, sampleLine: sampleLine))
		}

		#if DEBUG
		if Config.debugDrawSequencedEdgeDetection && debugSequenceId == Config.debugEdgeDetectionSequenceId
		{
			debugDrawEdgeDetail(debugBuffer: debugBuffer, sampleLine: sampleLine, windowSize: windowSize, minMaxWindowSize: minMaxWindowSize, overlap: overlap)
		}

		if Config.debugDrawMouseEdgeDetection && sampleLine.toLine().distance(to: Config.mousePosition) < 0.5
		{
			debugDrawEdgeDetail(debugBuffer: debugBuffer, sampleLine: sampleLine, windowSize: windowSize, minMaxWindowSize: minMaxWindowSize, overlap: overlap)
		}

		if Config.debugDrawEdges
		{
			var edgePos = sampleLine.interpolationPoint(sampleOffset: rollingSlopeOffset)
			edgePos.draw(to: debugBuffer, color: 0xa0ffff00)

			edgePos = sampleLine.interpolationPoint(sampleOffset: data.count - 1 - overlap / 2)
			edgePos.draw(to: debugBuffer, color: 0xa0ffff00)

			for edge in edgesDetected
			{
				edgePos = sampleLine.interpolationPoint(sampleOffset: edge.sampleOffset)
				edgePos.draw(to: debugBuffer, color: 0xa0ff0000)
			}
		}
		#endif

		return edgesDetected
	}

	/// Scans through the rolling sums looking for peaks that represent edges in the data
	///
	/// Ensure that `data` contains rolling sums (or scaled averages) prior to calling this function. After calling this method,
	/// `data` will remain unchanged and `peakValues` and `peakIndices` will contain the peak data.
	///
	/// The algorithm works by generating slopes from the rolling sum data. These slopes are calculated by taking the difference
	/// between two rolled sum values, offset by `rollingSlopeOffset`. An offset of `1` will use the difference between
	/// neighboring rolled sum values. However, an offset of `windowSize` will essentially compare two consecutive ranges of
	/// samples, providing a more robust difference calculation for edge detection.
	///
	/// Slope values are accumulated at points where the slope curve changes direction (i.e., peaks.) These peak slope values are
	/// stored in the `rolledPeaks` array.
	///
	/// It is important to note that slopes (and the peaks found within the slopes) are signed and their signs are used to
	/// determine if samples are trending toward darker samples (a negative slope value) or brighter samples (a positive slope.)
	/// This distinction is important because it allows us to determine if we're entering or leaving a mark. This additional data
	/// provides more context for determining actual features in the sample data and hence, can be used to more accurately match
	/// against a feature definition.
	private func findPeaks(rollingSlopeOffset: Int = 1) -> Bool
	{
		// Calculate our slope count (based on the number of rolling sums we can calculate slopes from)
		let maxSlopeCount = data.count - rollingSlopeOffset - 1

		// Reset our peak counts
		EdgeDetection.rolledPeaks.ensureReservation(capacity: maxSlopeCount)

		if maxSlopeCount <= 0 { return false }

		// Initialize our peak values
		var slopeMin: RollValue = RollValue.max
		var slopeMax: RollValue = 0
		var slopeTotal: RollValue = 0

		var dataIndex = 0
		while dataIndex < maxSlopeCount
		{
			// Prime the max of this slope direction
			var maxSlope = data[dataIndex + rollingSlopeOffset] - data[dataIndex]
			var maxSlopeIndex = dataIndex

			// Skip past the initial data point of this slope direction
			dataIndex += 1

			if maxSlope >= 0
			{
				// We are leaving a mark...
				while dataIndex < maxSlopeCount
				{
					let slope = data[dataIndex+rollingSlopeOffset] - data[dataIndex]
					if slope <= 0 { break }

					// Note the > operator: we keep the first of duplicates (>= would keep the last)
					if slope > maxSlope { maxSlope = slope; maxSlopeIndex = dataIndex }

					// Note that we step after storing the index, this stores the index in the last sample of the mark
					dataIndex += 1
				}
			}
			else if maxSlope <= 0
			{
				// We are entering a mark
				while dataIndex < maxSlopeCount
				{
					let slope = data[dataIndex+rollingSlopeOffset] - data[dataIndex]
					if slope >= 0 { break }

					// Note that we step before storing the index, this stores the index in the first sample of the mark
					dataIndex += 1

					// Note the <= operator: we keep the last of duplicates (< would keep the first)
					if slope <= maxSlope { maxSlope = slope; maxSlopeIndex = dataIndex }
				}
			}

			// We access the raw pointer here since we're not incrementing the count yet - these are temporary values
			//
			// Instead, we'll ensure that we don't exceed the capacity
			EdgeDetection.rolledPeaks.add(Peak(scaledPeakSlope: maxSlope, sampleOffset: maxSlopeIndex))

			let absSlope = abs(maxSlope)
			if absSlope < slopeMin { slopeMin = absSlope }
			if slopeMax < absSlope { slopeMax = absSlope }
			slopeTotal += absSlope
		}

		return true
	}

	/// Reduce a set of peaks to those that meet (or exceed) a localized threshold
	///
	/// The peaks are each compared against a threshold that is uniquely calculated for each peak using the `rolledMinMax` at that
	/// peak's position. For an alternative method of thresholding that does not use localized thresholds, see
	/// `thresholdPeaks(minMax:peakOffset:sensitivity:dataScale:)`.
	///
	/// The final set of peaks will include the correct sampleOffset where the peak was located along with the threshold used to
	/// detect that particular peak.
	private func thresholdPeaks(minMaxWindowSize: Int, peakOffset: Int, sensitivity: FixedPoint, dataScale: RollValue)
	{
		// We need to scale the minimum threshold in order to homogenize it with our data
		let scaledMinThreshold = Config.edgeMinimumThreshold * dataScale

		// Pre-calculate this to speed up the inner loop a bit
		let minMaxOffset = peakOffset - minMaxWindowSize / 2

		// As this is an in-place operation, we'll save off the current count, then reset the count so we can add the new elements
		let peakCount = EdgeDetection.rolledPeaks.count
		EdgeDetection.rolledPeaks.removeAll()

		for i in 0..<peakCount
		{
			// Get the min/max of the neighboring samples around the peak
			var peak = EdgeDetection.rolledPeaks._rawPointer[i]
			let absScaledPeakSlope = abs(peak.scaledPeakSlope)

			// We perform an early-out for most unusable peaks here
			if absScaledPeakSlope < scaledMinThreshold { continue }

			// Grab our min/max, properly offset into the min/max array (taking the peak's sample offset into account)
			//
			// Note that this can produce negative indices, so clamp them to 0 upon lookup
			let idx = peak.sampleOffset + minMaxOffset
			peak.minMax = EdgeDetection.rolledMinMax[idx < 0 ? 0 : idx]

			// Calculate the threshold for this single sample
			let threshold = EdgeDetection.calcThreshold(blackPoint: peak.minMax.min,
			                                            whitePoint: peak.minMax.max,
			                                            minThreshold: Config.edgeMinimumThreshold,
			                                            sensitivity: sensitivity) * dataScale

			// Store this peak if it meets the threshold
			if absScaledPeakSlope >= threshold
			{
				peak.sampleOffset += peakOffset
				peak.threshold = threshold
				EdgeDetection.rolledPeaks.add(peak)
			}
		}
	}

	/// Reduce a set of peaks to those that meet (or exceed) a non-localized threshold
	///
	/// The peaks are each compared against a threshold that is calculated only once for the entire set. For an alternative method
	/// of thresholding that uses localized thresholds, see `thresholdPeaks(minMaxWindowSize:peakOffset:sensitivity:dataScale:)`.
	///
	/// The final set of peaks will include the correct sampleOffset where the peak was located along with the threshold used to
	/// detect that particular peak.
	private func thresholdPeaks(minMax: MinMax<Sample>, peakOffset: Int, sensitivity: FixedPoint, dataScale: RollValue)
	{
		// Calculate the threshold for the entire set of peaks
		let threshold = EdgeDetection.calcThreshold(blackPoint: minMax.min,
		                                            whitePoint: minMax.max,
		                                            minThreshold: Config.edgeMinimumThreshold,
		                                            sensitivity: sensitivity) * dataScale

		// As this is an in-place operation, we'll save off the current count, then reset the count so we can add the new elements
		let peakCount = EdgeDetection.rolledPeaks.count
		EdgeDetection.rolledPeaks.removeAll()

		for i in 0..<peakCount
		{
			// Get the current peak
			var peak = EdgeDetection.rolledPeaks._rawPointer[i]

			// Store this peak if it meets the threshold
			if abs(peak.scaledPeakSlope) >= threshold
			{
				peak.minMax = minMax
				peak.sampleOffset += peakOffset
				peak.threshold = threshold
				EdgeDetection.rolledPeaks.add(peak)
			}
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Calculates a single threshold for use as a comparator against peak values, used to detect edges
	///
	/// The `sensitivity` parameter is a unit scalar representing how sensitive (0 = not sensitive at all, 1.0 = completely
	/// sensitive.)
	///
	/// The threshold calculation is simply a ratio (declared as `sensitivity`) from the `blackPoint` to the `whitePoint`, and
	/// clamped so that it does not fall below `minThreshold`.
	///
	/// The power of this threshold mechanism comes when the `blackPoint` and `whitePoint` are calculated from a rolling min/max
	/// over the localized area around the sample being tested.
	@inline(__always) class func calcThreshold(blackPoint: Sample, whitePoint: Sample, minThreshold: RollValue, sensitivity: FixedPoint) -> RollValue
	{
		let sampleRange = (whitePoint - blackPoint).toFixed()
		let threshold = RollValue((sensitivity * sampleRange).floor())

		// Limit our threshold to the minimum
		return threshold < minThreshold ? minThreshold : threshold
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	//													 ____       _
	//													|  _ \  ___| |__  _   _  __ _
	//													| | | |/ _ \ '_ \| | | |/ _` |
	//													| |_| |  __/ |_) | |_| | (_| |
	//													|____/ \___|_.__/ \__,_|\__, |
	//																			|___/
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	#if DEBUG
	/// Resets the debuggable edge sequence ID
	///
	/// This should be called at the start of each frame
	class func resetDebuggableEdgeDetectionSequence()
	{
		debuggableEdgeDetectionSequenceId = 0
	}

	/// Calculate the intermediate slopes used by the rollPeaks
	///
	/// Ensure that `sums` parameter contains rolling sums data. After calling this method, `data` will contain the slope data.
	///
	/// In order to focus on performance, the runtime code does not store a full set of slopes. Use this method to calculate the
	/// slopes for debugging visualization tools.
	private func debugRollSlope(sums: UnsafeMutableArray<RollValue>, rollingSlopeOffset: Int = 1) -> Bool
	{
		// We'll shorten our data by the offset amount
		let newCount = sums.count - rollingSlopeOffset

		// Ensure that we have enough data for a single sample
		if newCount < 0 { return false }

		for i in 0..<newCount
		{
			data.add(sums[i+rollingSlopeOffset] - sums[i])
		}

		return true
	}

	private func debugDrawEdgeDetail(debugBuffer: DebugBuffer?, sampleLine: SampleLine, windowSize: Int, minMaxWindowSize: Int, overlap: Int)
	{
		// Our data is out of scale by the window size
		let dataScale = Real(1.0) / Real(windowSize)

		// Samples graph
		var rawSamples = UnsafeMutableArray<Sample>(sampleLine.samples)
		debugDrawLineGraph(debugBuffer: debugBuffer, sampleLine: sampleLine, data: rawSamples, dataScale: 1, offset: 0, color: 0x40ff9575, amplitude: true)
		rawSamples.free()

		// minMax graph
		if minMaxWindowSize == 0
		{
			debugDrawMinMaxValue(debugBuffer: debugBuffer, sampleLine: sampleLine, dataScale: 1, offset: minMaxWindowSize/2, fillColor: 0x10ff88ff, lineColor: 0x40ff80ff, amplitude: true)
		}
		else if EdgeDetection.rolledMinMax.count > 1
		{
			debugDrawMinMaxGraph(debugBuffer: debugBuffer, sampleLine: sampleLine, data: EdgeDetection.rolledMinMax, dataScale: 1, offset: minMaxWindowSize/2, fillColor: 0x10ff88ff, lineColor: 0x40ff80ff, amplitude: true)
		}

		// Sums graph
		//
		// Each value represents the sum of the windowSize samples starting at the index. For display purposes, it can be thought
		// of as each sample represents the scaled average of samples surrounding the sample at offset `index + windowSize / 2`
		debugDrawLineGraph(debugBuffer: debugBuffer, sampleLine: sampleLine, data: data, dataScale: dataScale, offset: windowSize / 2, color: 0xff7595FF, amplitude: true)

		// Slopes graph
		//
		// Slopes represent the difference between two adjacent blocks of summed samples. We'll plot the graph on the pixel just
		// to the left of that meeting point.
		let slopes = EdgeDetection(predictedSize: data.count)
		if slopes.debugRollSlope(sums: self.data, rollingSlopeOffset: windowSize-overlap)
		{
			debugDrawFilledGraph(debugBuffer: debugBuffer, sampleLine: sampleLine, data: slopes.data, dataScale: dataScale, offset: windowSize-1-overlap/2, color: 0x400000ff)
			debugDrawLineGraph(debugBuffer: debugBuffer, sampleLine: sampleLine, data: slopes.data, dataScale: dataScale, offset: windowSize-1-overlap/2, color: 0xff0000ff)
		}

		// Draw the sample line
		sampleLine.draw(to: debugBuffer, color: 0xffff0000)

		// Peaks graph
		//
		// Peaks represent the slope values that have been filtered to remove any slope value that is co-linear with its neighbors.
		debugDrawPeaksGraph(debugBuffer: debugBuffer, sampleLine: sampleLine, edges: edgesDetected, dataScale: dataScale, color: 0xffffff00)
	}

	private func debugDrawPointGraph(debugBuffer: DebugBuffer?, sampleLine: SampleLine, data: UnsafeMutableArray<RollValue>, dataScale: Real, offset: Int, color: Color, amplitude: Bool = false)
	{
		if debugBuffer == nil { return }

		let perpNormal = sampleLine.toLine().perpendicularNormal

		for sign in amplitude ? [-1, 1] : [1]
		{
			let signedPerpNormal = perpNormal * Real(sign)
			for i in 1..<data.count
			{
				let d = Real(data[i]) * dataScale
				let p = sampleLine.interpolationPoint(sampleOffset: i + offset).toVector() + signedPerpNormal * d
				p.chopToPoint().draw(to: debugBuffer, color: color)
			}
		}
	}

	private func debugDrawPointGraph(debugBuffer: DebugBuffer?, sampleLine: SampleLine, value: RollValue, dataScale: Real, color: Color)
	{
		if debugBuffer == nil { return }

		let d = Real(value) * dataScale
		let perpNormal = sampleLine.toLine().perpendicularNormal * d

		for i in 0..<sampleLine.sampleCount
		{
			let p = sampleLine.interpolationPoint(sampleOffset: i)

			let p0 = p.toVector() - perpNormal
			let p1 = p.toVector() + perpNormal
			p0.chopToPoint().draw(to: debugBuffer, color: color)
			p1.chopToPoint().draw(to: debugBuffer, color: color)
		}
	}

	private func debugDrawLineGraph(debugBuffer: DebugBuffer?, sampleLine: SampleLine, data: UnsafeMutableArray<RollValue>, dataScale: Real, offset: Int, color: Color, amplitude: Bool = false)
	{
		if debugBuffer == nil { return }

		let perpNormal = sampleLine.toLine().perpendicularNormal

		for sign in amplitude ? [-1, 1] : [1]
		{
			let signedPerpNormal = perpNormal * Real(sign)
			let d = Real(data[0]) * dataScale
			var p0 = sampleLine.interpolationPoint(sampleOffset: offset).toVector() + signedPerpNormal * d
			for i in 1..<data.count
			{
				let d = Real(data[i]) * dataScale
				let p1 = sampleLine.interpolationPoint(sampleOffset: i + offset).toVector() + signedPerpNormal * d
				let pp1 = p1.chopToPoint()
				SampleLine(p0: p0.chopToPoint(), p1: pp1).draw(to: debugBuffer, color: color)
				pp1.draw(to: debugBuffer, color: color | 0xff000000)
				p0 = p1
			}
		}
	}

	private func debugDrawMinMaxGraph(debugBuffer: DebugBuffer?, sampleLine: SampleLine, data: UnsafeMutableArray<MinMax<Sample>>, dataScale: Real, offset: Int, fillColor: Color, lineColor: Color, amplitude: Bool = false)
	{
		if debugBuffer == nil { return }

		let perpNormal = sampleLine.toLine().perpendicularNormal

		for sign in amplitude ? [-1, 1] : [1]
		{
			let signedPerpNormal = perpNormal * Real(sign)
			var p0Max = sampleLine.interpolationPoint(sampleOffset: offset).toVector() - signedPerpNormal * Real(data[0].max) * dataScale
			var p0Min = sampleLine.interpolationPoint(sampleOffset: offset).toVector() - signedPerpNormal * Real(data[0].min) * dataScale
			SampleLine(p0: p0Max.chopToPoint(), p1: p0Min.chopToPoint()).draw(to: debugBuffer, color: fillColor)
			for i in 1..<data.count
			{
				let p1Max = sampleLine.interpolationPoint(sampleOffset: i + offset).toVector() - signedPerpNormal * Real(data[i].max) * dataScale
				let p1Min = sampleLine.interpolationPoint(sampleOffset: i + offset).toVector() - signedPerpNormal * Real(data[i].min) * dataScale
				SampleLine(p0: p1Max.chopToPoint(), p1: p1Min.chopToPoint()).draw(to: debugBuffer, color: fillColor)

				SampleLine(p0: p0Min.chopToPoint(), p1: p1Min.chopToPoint()).draw(to: debugBuffer, color: lineColor)
				SampleLine(p0: p0Max.chopToPoint(), p1: p1Max.chopToPoint()).draw(to: debugBuffer, color: lineColor)
				p0Max = p1Max
				p0Min = p1Min
			}
		}
	}

	private func debugDrawMinMaxValue(debugBuffer: DebugBuffer?, sampleLine: SampleLine, dataScale: Real, offset: Int, fillColor: Color, lineColor: Color, amplitude: Bool = false)
	{
		if debugBuffer == nil { return }

		let minMax = sampleLine.samples.getMinMax()
		let minVal = Real(minMax.min) * dataScale
		let maxVal = Real(minMax.max) * dataScale

		let perpNormal = sampleLine.toLine().perpendicularNormal

		for sign in amplitude ? [-1, 1] : [1]
		{
			let signedPerpNormal = perpNormal * Real(sign)
			var p0 = sampleLine.interpolationPoint(sampleOffset: offset).toVector()
			var p0Max = p0 - signedPerpNormal * maxVal
			var p0Min = p0 - signedPerpNormal * minVal
			for i in 0..<sampleLine.sampleCount
			{
				let p1 = sampleLine.interpolationPoint(sampleOffset: i + offset).toVector()
				let p1Max = p1 - signedPerpNormal * maxVal
				let p1Min = p1 - signedPerpNormal * minVal
				SampleLine(p0: p1Max.chopToPoint(), p1: p1Min.chopToPoint()).draw(to: debugBuffer, color: fillColor)
				SampleLine(p0: p0Min.chopToPoint(), p1: p1Min.chopToPoint()).draw(to: debugBuffer, color: lineColor)
				SampleLine(p0: p0Max.chopToPoint(), p1: p1Max.chopToPoint()).draw(to: debugBuffer, color: lineColor)
				p0 = p1
				p0Max = p1Max
				p0Min = p1Min
			}
		}
	}

	private func debugDrawFilledGraph(debugBuffer: DebugBuffer?, sampleLine: SampleLine, data: UnsafeMutableArray<RollValue>, dataScale: Real, offset: Int, color: Color)
	{
		if debugBuffer == nil { return }

		let perpNormal = sampleLine.toLine().perpendicularNormal

		for i in 0..<data.count
		{
			let d = Real(data[i]) * dataScale
			let p0 = sampleLine.interpolationPoint(sampleOffset: i + offset)
			let p1 = p0.toVector() + perpNormal * d
			SampleLine(p0: p0, p1: p1.chopToPoint()).draw(to: debugBuffer, color: color)
		}
	}

	private func debugDrawFilledGraph(debugBuffer: DebugBuffer?, sampleLine: SampleLine, value: RollValue, dataScale: Real, color: Color)
	{
		if debugBuffer == nil { return }

		let d = Real(value) * dataScale
		let perpNormal = sampleLine.toLine().perpendicularNormal * d

		for i in 0..<sampleLine.sampleCount
		{
			let p = sampleLine.interpolationPoint(sampleOffset: i)

			let p0 = p.toVector() - perpNormal
			let p1 = p.toVector() + perpNormal
			SampleLine(p0: p0.chopToPoint(), p1: p1.chopToPoint()).draw(to: debugBuffer, color: color)
		}
	}

	private func debugDrawPeaksGraph(debugBuffer: DebugBuffer?, sampleLine: SampleLine, edges: [Edge], dataScale: Real, color: Color)
	{
		if debugBuffer == nil { return }
		if edges.count == 0 { return }

		let perpNormal = sampleLine.toLine().perpendicularNormal

		for edge in edges
		{
			let d = Real(edge.slope) * dataScale
			let p0 = sampleLine.interpolationPoint(sampleOffset: edge.sampleOffset)
			let p1 = p0.toVector() + perpNormal * d
			SampleLine(p0: p0, p1: p1.chopToPoint()).draw(to: debugBuffer, color: color)
		}

		for sign in [-1, 1]
		{
			let signedPerpNormal = perpNormal * Real(sign)
			var t0 = sampleLine.interpolationPoint(sampleOffset: edges[0].sampleOffset).toVector() + signedPerpNormal * Real(edges[0].threshold) * dataScale
			for edge in edges
			{
				let t1 = sampleLine.interpolationPoint(sampleOffset: edge.sampleOffset).toVector() + signedPerpNormal * Real(edge.threshold) * dataScale
				SampleLine(p0: t0.chopToPoint(), p1: t1.chopToPoint()).draw(to: debugBuffer, color: 0xff00ff00)
				t0 = t1
			}
		}
	}
	#endif
}
