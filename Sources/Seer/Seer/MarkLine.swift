//
//  MarkLine.swift
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

/// Defines a line within the image that encompasses the portion of the deck where this mark resides
final class MarkLine
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The type of the mark that this line represents
	let markType: MarkType

	/// The binarized image samples along the SampleLine forming a column of bits
	var bitColumn: UnsafeMutableArray<Bool>?

	/// Sharpness: A unit scalar denoting the relative maximum sharpness of the samples captured from this mark line
	///
	/// Not used when `Config.decodeEnableSharpnessDetection` is set to `false`
	var maxSharpnessUnitScalar: FixedPoint = 0

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a MarkLine with the essentials
	init(debugBuffer: DebugBuffer?, markType: MarkType, sampleLine: SampleLine, deckFormat: DeckFormat)
	{
		self.markType = markType
		let samples = sampleLine.samples

		// Binarize the samples into bit marks
		if markType.isBit
		{
			// We remove a fraction of the sample line from the start/end in order to ensure that we're getting just the bit marks
			// and not dealing with potentially overblown (too white due to lighting) samples near the edge of the deck.
			let fraction = sampleLine.sampleCount / 20
			let mmStart = fraction
			let mmCount = sampleLine.sampleCount - fraction * 2

			// Calculate the threshold for binarizing the samples using the combined min/max from all mark lines
			let singleMinMax = samples.getMinMax(start: mmStart, count: mmCount)
//			let average = sampleLine.calcAverage()
//			let adjustedAverage = Sample((Config.decodeMarkLineAverageOffsetMultiplier * average).floor())

			// We calculate the center of the min/max, then use the offset multiplier to adjust toward min (0.0) or max (1.0)
			let adjustedAverage = singleMinMax.min + Sample((Config.decodeMarkLineAverageOffsetMultiplier * singleMinMax.range()).floor())
			let threshold = max(adjustedAverage, Config.edgeMinimumThreshold)

			// Calculate the sharpness for the mark line
			if Config.decodeEnableSharpnessDetection
			{
				let range = singleMinMax.range()
				let debugRefIndex = markType.bitIndex!
				let debugRefCount = markType.bitCount!
				maxSharpnessUnitScalar = sampleLine.calcMaxSharpnessUnitScalar(debugBuffer: debugBuffer, start: mmStart, count: mmCount, minRange: deckFormat.getMinSampleHeight(), amplitude: range, debugRefIndex: debugRefIndex, debugRefCount: debugRefCount)
			}

			// Allocate our bit column
			bitColumn = UnsafeMutableArray<Bool>(withCapacity: sampleLine.sampleCount)

			// We use a weighted average of the samples along the mark line, such that the center sample gets twice the weight
			// of its neighbors
			//
			// Start by adding the first raw sample
			let end = sampleLine.sampleCount - 1
			bitColumn!.add(samples[0] < threshold)
			if sampleLine.sampleCount > 1
			{
				for i in 1..<end
				{
					let tmp = (samples[i-1] + samples[i]*6 + samples[i+1]) / 8
					bitColumn!.add(tmp < threshold)
				}
				bitColumn!.add(samples[end] < threshold)
			}
		}
	}

	/// Cleans up our MarkLine and free all resources used by it
	deinit
	{
		bitColumn?.free()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns a new bitColumn which has been resampled to a new length
	///
	/// The caller is responsible for freeing the memory from the returned array when they are done with it.
	///
	/// If the original bit column is already at the length requested, then a new bitColumn is allocated and the contents of this
	/// MarkLine's bitColumn is simply copied over.
	///
	/// As the original array is an array of boolean values, the resample must choose nearest neighbor. It does this via a proper
	/// rounding method (optimized).
	func resampledBitColumn(to resampleCount: Int) -> UnsafeMutableArray<Bool>
	{
		// We must have a bit column
		assert(bitColumn != nil)

		// Allocate a new bitColumns array
		var newBits = UnsafeMutableArray<Bool>(withCapacity: resampleCount)

		// If our column is already the correct length, just return it
		if bitColumn!.count == resampleCount
		{
			newBits.assign(from: bitColumn!._rawPointer, count: bitColumn!.count)
		}
		else
		{
			// Delta through the bits
			let delta = bitColumn!.count.toFixed() / resampleCount.toFixed()

			// Similar to the approach used by Bresenham line drawing, we add half the delta in order to center our error inside
			// the full range.
			var index = delta >> 1

			for _ in 0..<resampleCount
			{
				newBits.add(bitColumn![index.floor()])
				index += delta
			}
		}

		// Sanity check
		assert(newBits.count == resampleCount)

		return newBits
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension MarkLine: CustomStringConvertible, CustomDebugStringConvertible
{
	var debugDescription: String
	{
		return description
	}

	var description: String
	{
		var str = ""
		if markType.isBit
		{
			str = String(format: "Bit %2d: ", arguments: [markType.bitIndex!])
			for bit in 0..<bitColumn!.count
			{
				str += "\(bitColumn![bit] ? "X":"_")"
			}
		}
		else
		{
			str = String(describing: markType)
		}
		return str
	}
}
