//
//  MarkLines.swift
//  Seer
//
//  Created by pn on 12/6/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

// ---------------------------------------------------------------------------------------------------------------------------------
// Local constants
// ---------------------------------------------------------------------------------------------------------------------------------

/// Represents a collection of MarkLines for a DeckLocation.
///
/// More than a simple collection, MarkLines also stores information related to the collection, such as the matched range (the
/// range defining the subset of each line that is known to intersect the actual deck) and the CodeDefinition that the collection
/// is related to.
public final class MarkLines
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Custom types
	// -----------------------------------------------------------------------------------------------------------------------------

	public typealias BitWord = Int32

	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The growth scalar for all allocations used by the MarkLines
	private static let kAllocationGrowthScalar: FixedPoint = 2

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Our bit words, stored in a static to avoid re-allocation when not necessary
	///
	/// It is initialized to an arbitrary capacity, which will get resized on the first run to a more representative capacity and
	/// will grow only when necessary.
	private var bitWords = UnsafeMutableArray<BitWord>(withCapacity: 1024)

	/// Our resampled bit columns, stored in a static to avoid re-allocation when not necessary
	///
	/// It is initialized to an arbitrary capacity, which will get resized on the first run to a more representative capacity and
	/// will grow only when necessary.
	private var resampledBitColumns = StaticMatrix<Bool>(rowCapacity: 1024, colCapacity: 25)

	/// Storage for the bit marks when generating contoured mark lines
	private var bitMarkMatrix = StaticMatrix<Sample>(rowCapacity: 25, colCapacity: 1024)

	/// Our mark lines
	private(set) var markLines = [MarkLine]()

	/// Returns the first MarkLine
	var first: MarkLine { return markLines.first! }

	/// Returns the last MarkLine
	var last: MarkLine { return markLines.last! }

	/// Returns the number of mark lines
	var count: Int { return markLines.count }

	/// Returns the mark line for a given index
	subscript(index: Int) -> MarkLine { return markLines[index] }

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Collect bit mark samples from the lumaBuffer for the given DeckMatchResult
	///
	/// For contoured bit marks, see `generateContouredMarkLines()`
	///
	/// This process maximizes precision by normalizing the bit mark locations to the nearest bounding set of landmarks. These
	/// landmarks can be found in the CodeDefinition (see bitNeighboringLandmarks.) As such, it is important that bottomLine and
	/// topLine extend only through those landmarks.
	///
	/// More specifically, ensure that bottomLine and topLine extend from the center of the first bit-neighboring landmark to the
	/// center of the last bit-neighboring landmark.
	func generateLinearMarkLines(debugBuffer: DebugBuffer?, lumaBuffer: LumaBuffer, codeDefinition: CodeDefinition, match: DeckMatchResult, topLine inTopLine: SampleLine, bottomLine inBottomLine: SampleLine) -> Bool
	{
		// We'll need our definitions for each mark
		let bitMarkDefinitions = codeDefinition.bitMarks
		let bitCount = bitMarkDefinitions.count

		// Prepare our mark lines
		markLines.removeAll()
		markLines.reserveCapacity(bitCount)

		// We're only concerned with bit-neighboring landmarks
		let landmarks = codeDefinition.bitNeighboringLandmarks
		let lLandmark = landmarks.first!
		let rLandmark = landmarks.last!

		// This is our definition range. We'll call this "definition space".
		//
		// It is actually a partial range of the full CodeDefinition and we're normalizing to just the range of landmarks that
		// encompass the bit marks. However, as that is what we're normalizing to, that is our entire world.
		let definitionRange = (rLandmark.centerMM - lLandmark.centerMM)

		// Convert our SampleLines to Lines so we have more precision to work with
		let topLine = inTopLine.toLine()
		let bottomLine = inBottomLine.toLine()

		// Visit each local range of bit marks that lie between landmarks
		//
		// In each iteration, we'll be working on a "local space". There are multiple local spaces, one per group of bit marks
		// that get normalized to their neighboring landmarks.
		var bitMarkDefinitionIndex = 0
		for i in 0..<landmarks.count - 1
		{
			// The left/right landmarks that we'll use to normalize this set of bit marks into the current local range
			let leftLandmark = landmarks[i]
			let rightLandmark = landmarks[i+1]

			// Normalize the bits between these landmarks
			guard let normalizedBitMarkCenters = codeDefinition.normalizeBitMarks(from: leftLandmark, to: rightLandmark) else { return false }

			// Create a scale that will get us from "definition space" into "local space"
			let leftCenter = leftLandmark.centerMM
			let localRange = rightLandmark.centerMM - leftCenter
			let localSpaceScale = localRange / definitionRange

			// Create an offset that will move us from local space to local space as we visit each group of bit marks
			let localSpaceOffset = (leftCenter - lLandmark.centerMM) / localRange

			// Scale our vectors from definition space into local space
			let topVector = topLine.vector * localSpaceScale
			let bottomVector = bottomLine.vector * localSpaceScale

			// Offset our starting points to the appropriate local space
			let topStart = topLine.p0 + topVector * localSpaceOffset
			let bottomStart = bottomLine.p0 + bottomVector * localSpaceOffset

			// Reserve our mark lines
			markLines.reserveCapacity(normalizedBitMarkCenters.count)

			// Finally, generate a set of MarkLines for this local space
			for centerOffset in normalizedBitMarkCenters
			{
				// Calculate the center top and bottom offsets of this bit mark within the local space
				let p0 = topStart + topVector * centerOffset
				let p1 = bottomStart + bottomVector * centerOffset

				// Sample the bit mark line (using a wide sample)
				let sampleLine = SampleLine(line: Line(p0: p0, p1: p1))
				if !sampleLine.sampleWide(from: lumaBuffer) { return false }

				// Create a new MarkLine from this SampleLine
				let markLine = MarkLine(debugBuffer: debugBuffer, markType: bitMarkDefinitions[bitMarkDefinitionIndex].type, sampleLine: sampleLine, deckFormat: codeDefinition.format)
				bitMarkDefinitionIndex += 1

				// Add the mark line to our set
				markLines.append(markLine)

				if Config.debugDrawMarkLines
				{
					sampleLine.draw(to: debugBuffer, color: kDebugMarkLineColor)

					if let bitColumn = markLine.bitColumn
					{
						let col = kDebugMarkBitColor

						for i in 0..<bitColumn.count
						{
							if bitColumn[i]
							{
								sampleLine.interpolationPoint(sampleOffset: i).draw(to: debugBuffer, color: col)
							}
						}
					}
				}
			}
		}

		return true
	}

	/// Collects contoured bit mark samples from the `lumaBuffer` by interpolating bit columns between the `leftCenters` and
	/// `rightCenters` arrays.
	///
	/// For linear bit marks, see `generateLinearMarkLines()`
	///
	/// The two parameters, `leftCenters` and `rightCenters` represent the center points of the bit-neighboring LandMarks, from the
	/// top of the deck to the bottom of the deck. They are interpolated simultaneously (and equally) in order to produce a series
	/// of lines that scan down the face of the deck from the top down. During this process, image is sampled at the bit mark
	/// locations and used to generate a series of SampleLines with custom data, which are then used to create the set of MarkLine
	/// objects.
	///
	/// This process maximizes precision by normalizing the bit mark locations to the nearest bounding set of LandMarks. These
	/// landmarks can be found in the CodeDefinition (see bitNeighboringLandmarks.) As such, it is important that bottomLine and
	/// topLine extend only through those LandMarks.
	func generateContouredMarkLines(debugBuffer: DebugBuffer?, lumaBuffer: LumaBuffer, codeDefinition: CodeDefinition, match: DeckMatchResult, leftCenters: UnsafeBidirectionalArray<IVector>, rightCenters: UnsafeBidirectionalArray<IVector>) -> Bool
	{
		// We'll need our definitions for each mark
		let bitMarkDefinitions = codeDefinition.bitMarks
		let bitCount = bitMarkDefinitions.count
		let invertSampleLuma = codeDefinition.format.invertLuma

		// Prepare our mark lines
		markLines.removeAll()
		markLines.reserveCapacity(bitCount)

		// We're only concerned with bit-neighboring landmarks
		let landmarks = codeDefinition.bitNeighboringLandmarks
		let lLandmark = landmarks.first!
		let rLandmark = landmarks.last!

		// Calculate our normalized bit mark centers so we can locate them between the bit neighboring LandMarks
		guard let normalizedBitMarkCenters = codeDefinition.normalizeBitMarks(from: lLandmark, to: rLandmark) else { return false }

		// Calculate our interpolation deltas for the indices into the left/right LandMark centers
		let lCenters = leftCenters.interpolatedData
		let rCenters = rightCenters.interpolatedData
		let scanlineCount = max(lCenters.count, rCenters.count)
		let lCentersDeltaIndex = FixedPoint(lCenters.count) / scanlineCount
		let rCentersDeltaIndex = FixedPoint(rCenters.count) / scanlineCount

		// Do we need to grow our matrix?
		bitMarkMatrix.ensureReservation(rowCapacity: bitCount, colCapacity: scanlineCount, colGrowthScalar: MarkLines.kAllocationGrowthScalar)

		if invertSampleLuma
		{
			for scanlineIndex in 0..<scanlineCount
			{
				let lPoint = lCenters[(lCentersDeltaIndex * scanlineIndex).floor()].toVector()
				let rPoint = rCenters[(rCentersDeltaIndex * scanlineIndex).floor()].toVector()
				let normal = (rPoint - lPoint).normal()

				// Collect the samples for each column of bits
				for bit in 0..<bitCount
				{
					let bitMarkCenter = normalizedBitMarkCenters[bit]
					let bitLoc = lPoint + (rPoint - lPoint) * bitMarkCenter
					let b = Sample(Luma(255)-lumaBuffer.sample(from: (bitLoc         ).chopToPoint())!)
					let a = Sample(Luma(255)-lumaBuffer.sample(from: (bitLoc - normal).chopToPoint())!)
					let c = Sample(Luma(255)-lumaBuffer.sample(from: (bitLoc + normal).chopToPoint())!)
					let sample = (a + b * 6 + c) / 8
					bitMarkMatrix.add(toRow: bit, value: sample)
				}
			}
		}
		else
		{
			for scanlineIndex in 0..<scanlineCount
			{
				let lPoint = lCenters[(lCentersDeltaIndex * scanlineIndex).floor()].toVector()
				let rPoint = rCenters[(rCentersDeltaIndex * scanlineIndex).floor()].toVector()
				let normal = (rPoint - lPoint).normal()

				// Collect the samples for each column of bits
				for bit in 0..<bitCount
				{
					let bitMarkCenter = normalizedBitMarkCenters[bit]
					let bitLoc = lPoint + (rPoint - lPoint) * bitMarkCenter
					let b = Sample(lumaBuffer.sample(from: (bitLoc         ).chopToPoint())!)
					let a = Sample(lumaBuffer.sample(from: (bitLoc - normal).chopToPoint())!)
					let c = Sample(lumaBuffer.sample(from: (bitLoc + normal).chopToPoint())!)
					let sample = (a + b * 6 + c) / 8
					bitMarkMatrix.add(toRow: bit, value: sample)
				}
			}
		}

		let lTop = lCenters[0].toVector()
		let rTop = rCenters[0].toVector()
		let lBot = lCenters[lCenters.count-1].toVector()
		let rBot = rCenters[rCenters.count-1].toVector()
		for bit in 0..<bitCount
		{
			let bitMarkCenter = normalizedBitMarkCenters[bit]
			let p0 = (lTop + (rTop - lTop) * bitMarkCenter).chopToPoint()
			let p1 = (lBot + (rBot - lBot) * bitMarkCenter).chopToPoint()
			let sampleLine = SampleLine(p0: p0, p1: p1, withMatrix: bitMarkMatrix, rowIndex: bit)
			let markLine = MarkLine(debugBuffer: debugBuffer, markType: bitMarkDefinitions[bit].type, sampleLine: sampleLine, deckFormat: codeDefinition.format)
			markLines.append(markLine)

			if Config.debugDrawMarkLines
			{
				for scanlineIndex in 0..<scanlineCount
				{
					let lIndex = (lCentersDeltaIndex * scanlineIndex).floor()
					let rIndex = (rCentersDeltaIndex * scanlineIndex).floor()

					let lPoint = lCenters[lIndex].toVector()
					let rPoint = rCenters[rIndex].toVector()

					let bitLoc = lPoint + (rPoint - lPoint) * normalizedBitMarkCenters[bit]
					let p = bitLoc.chopToPoint()
					p.draw(to: debugBuffer, color: markLine.bitColumn![scanlineIndex] ? kDebugMarkBitColor : kDebugMarkLineColor)
				}
			}
		}

		return true
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Bit management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns an array of integers that each contain the combined bits from the resampled mark line columns.
	///
	/// In order for the combined bits to fit within the result type, the number of bit columns must not be more than the bit
	/// width of the type returned.
	///
	/// The `maxCardCount` parameter can be had by getting the `maxCardCount` from the `DeckFormat`
	///
	/// The bits in each row value are ordered such that the LSB contains the bit for the first bit column, with increasing
	/// bit offsets (towards MSB) with each bit column.
	///
	/// This function will return nil if an error occurs.
	func generateBitWords(maxCardCount: Int) -> UnsafeMutableArray<BitWord>?
	{
		// Get a resampled set of bit columns
		let columnCount = (Config.decodeResampleBitColumnLengthMultiplier * maxCardCount).floor()
		guard let bitColumns = resampleBitColumns(to: columnCount) else { return nil }
		let colCount = bitColumns.colCount(row: 0)

		// If you hit this assert, you have too many bit columns to fit within the value return type
		assert(bitColumns.rowCapacity <= MemoryLayout<BitWord>.size * 8)
		if bitColumns.rowCapacity > MemoryLayout<BitWord>.size * 8 { return nil }

		// Setup our value array
		bitWords.ensureReservation(capacity: colCount, growthScalar: MarkLines.kAllocationGrowthScalar)

		// Scan the each row of bits in the mark lines, combining bits into a single word for each bit in the column
		for i in 0..<colCount
		{
			var value: BitWord = 0
			for j in 0..<count
			{
				if bitColumns[j, i]
				{
					value += 1 << BitWord(j)
				}
			}

			bitWords.add(value)
		}

		return bitWords
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Sharpness
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the minimum of the set of maximum sharpness values from all mark lines
	func calcMinimumSharpness() -> FixedPoint
	{
		if markLines.count == 0 { return 0 }

		var minimumSharpness = markLines[0].maxSharpnessUnitScalar
		for i in 1..<markLines.count
		{
			assert(markLines[i].markType.isBit)
			minimumSharpness = min(markLines[i].maxSharpnessUnitScalar, minimumSharpness)
		}

		return minimumSharpness
	}

	/// Returns the average maximum sharpness from all mark lines
	func calcAverageSharpness() -> FixedPoint
	{
		if markLines.count == 0 { return 0 }

		var total = markLines[0].maxSharpnessUnitScalar
		for i in 1..<markLines.count
		{
			assert(markLines[i].markType.isBit)
			total += markLines[i].maxSharpnessUnitScalar
		}

		return total / markLines.count
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns an array of identical-length bit columns
	///
	/// The length of each array returned will be equal to the length of the longest bit column from the original set of MarkLines.
	/// In order to do this, the bits are resampled (see MarkLine.resampledBits() for details on how this is done.)
	///
	/// This routine will return nil if there are no bit columns to resample (it will not return an empty array.)
	private func resampleBitColumns(to resampleCount: Int) -> StaticMatrix<Bool>?
	{
		// Sanity check
		if resampleCount == 0 || markLines.count == 0 { return nil }

		// Do we need to grow our matrix?
		resampledBitColumns.ensureReservation(rowCapacity: markLines.count, colCapacity: resampleCount, colGrowthScalar: MarkLines.kAllocationGrowthScalar)

		// Resample each MarkLine. Note that the resample process will return its own array if no resample is needed
		for markLineIndex in 0..<markLines.count
		{
			var bitColumn = markLines[markLineIndex].resampledBitColumn(to: resampleCount)
			for bitColumnIndex in 0..<bitColumn.count
			{
				resampledBitColumns.add(toRow: markLineIndex, value: bitColumn[bitColumnIndex])
			}
			bitColumn.free()
		}

		// Return the newly resampled bit columns, or nil if there aren't any
		return resampledBitColumns
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Debug
	// -----------------------------------------------------------------------------------------------------------------------------

	func debugDrawHistogram(debugBuffer: DebugBuffer?)
	{
		// Draw a histogram of our bit widths
		var counts = [Int]()
		for ml in markLines
		{
			if let bitColumns = ml.bitColumn
			{
				var index = 0
				while index < bitColumns.count
				{
					// We only want set bits
					var count = 1
					if bitColumns[index]
					{
						for j in index+1..<bitColumns.count
						{
							if !bitColumns[j] { break }
							count += 1
						}

						counts.append(count)
					}
					index += count
				}
			}
		}

		debugBuffer?.drawHistogram(data: counts)
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension MarkLines: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		var str = "\(markLines.count) lines\(String.kNewLine)"

		for i in 0..<20
		{
			str += "  "
			for line in markLines
			{
				if let bm = line.bitColumn
				{
					if i < bm.count
					{
						str += bm[i] ? "X":"-"
					}
				}
			}
			str += String.kNewLine
		}

		str += "  ~~~~~~~~~~~~" + String.kNewLine

		for i in 0..<20
		{
			str += "  "
			for line in markLines
			{
				if let bm = line.bitColumn
				{
					if i < bm.count
					{
						str += bm[bm.count - 20 + i] ? "X":"-"
					}
				}
			}
			str += String.kNewLine
		}
		return str
	}
}
