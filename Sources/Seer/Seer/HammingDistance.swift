//
//  HammingDistance.swift
//  Seer
//
//  Created by Paul Nettle on 3/13/17.
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

public final class HammingDistance
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The error correction maps may have a real code or one of these values denoting the given state
	public enum CardState: Int
	{
		/// Represents a value in the error correction map that has not yet been assigned
		case Unassigned = -1
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Hamming distances
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the Hamming Distance between two codes of `bitCount` bits each
	///
	/// The Hamming Distance is essentially the number of bits that are different between two codes
	@inline(__always) public class func calcHammingDistance(from a: Int, to b: Int) -> Int
	{
		var diffBits = a ^ b
		var hammingDistance = 0

		while diffBits != 0
		{
			hammingDistance += 1
			diffBits &= diffBits - 1
		}

		return hammingDistance
	}

	@inline(__always) public class func calcMinimumDistance(for codes: UnsafeMutableArray<Int>, codeBits: Int, reversible: Bool = false, bestMinimumDistance: Int = 0) -> Int
	{
		// If the codes are reversible, calculate the dinimum distance of an array with the original set and revesible set
		if reversible
		{
			var reversibleCodes = UnsafeMutableArray<Int>(withCapacity: codes.count * 2)
			defer { reversibleCodes.free() }

			for i in 0..<codes.count
			{
				reversibleCodes.add(codes[i])
				reversibleCodes.add(codes[i].reversedBits(bitCount: codeBits))
			}

			return calcMinimumDistance(for: reversibleCodes, codeBits: codeBits, reversible: false, bestMinimumDistance: bestMinimumDistance)
		}

		var mds = codeBits
		for i in 0..<codes.count
		{
			let iCode = codes[i]
			for j in i+1..<codes.count
			{
				mds = min(mds, calcHammingDistance(from: iCode, to: codes[j]))
			}

			if mds < bestMinimumDistance { return 0 }
		}

		return mds
	}

	/// Produces a 2D distance map of Hamming Distances between each pair of codes from `codes'. In addition, each line in the string
	/// can be prefixed, which is useful for indentation.
	public class func generateHammingDistanceMap(codes: UnsafeMutableArray<Int>, prefix: String = "") -> String
	{
		var matrixHeader = prefix + "    "
		var matrixData = ""
		for i in 0..<codes.count
		{
			let valStr = (i+1).toString(2)

			// Build up a header of the face codes for this DeckFormat
			matrixHeader += valStr + " "

			// Generate a row for the matrix
			matrixData += prefix + "\(valStr): "

			let aCode = codes[i]
			for j in 0..<codes.count
			{
				let bCode = codes[j]

				// If it's the same code, just just add an empty element to the row
				if aCode == bCode
				{
					matrixData += "   "
					continue
				}

				// Get the hamming distance and add it to the histogram
				let hammingDistance = calcHammingDistance(from: aCode, to: bCode)

				// Add an element to this row
				matrixData += hammingDistance.toString(2) + " "
			}

			// Terminate this row and move on to the next
			matrixData += String.kNewLine
		}

		return matrixHeader + String.kNewLine + matrixData
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Error correction
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Calculates the mapping of raw codes to the nearest real code (via MDS)
	///
	/// As expected, any direct hits will contain the same code at the code's position in the array
	public class func calcErrorCorrectedMaps(formatName: String, bitCount: Int, mapIndexToCode: [Int]) -> (mapCodeToErrorCorrectedCode: [Int], mapCodeToErrorCorrectedIndex: [Int])
	{
		let kFullRange = Int(1) << bitCount
		let kCollision = -2

		// Initialize the maps
		//
		// Note that during processing, the `mapCodeToErrorCorrectedCode` does double-duty. Card Codes are stored with the
		// minimum distance for all Card Codes in the upper bits.
		var mapCodeToErrorCorrectedCode = [Int](repeating: CardState.Unassigned.rawValue, count: kFullRange)
		var mapDistToErrorCorrectedCode = [Int8](repeating: Int8(bitCount), count: kFullRange)
		var mapCodeToErrorCorrectedIndex = [Int](repeating: CardState.Unassigned.rawValue, count: kFullRange)

		for cardIndex in 0..<mapIndexToCode.count
		{
			let cardCode = mapIndexToCode[cardIndex]

			for possibleValue in 0..<kFullRange
			{
				let possibleValueIndex = possibleValue

				// Calculate the distance
				let distance = HammingDistance.calcHammingDistance(from: possibleValue, to: cardCode)

				let minValue = mapCodeToErrorCorrectedCode[possibleValueIndex]
				let minDistance = mapDistToErrorCorrectedCode[possibleValueIndex]

				// If it's a better distance just assign it
				if distance < minDistance
				{
					mapCodeToErrorCorrectedCode[possibleValueIndex] = cardCode
					mapDistToErrorCorrectedCode[possibleValueIndex] = Int8(distance)
					mapCodeToErrorCorrectedIndex[possibleValueIndex] = cardIndex
					continue
				}

				// If we have a distance collision, mark it as a collision and the distance at which we collided
				if distance == minDistance
				{
					// Don't bother marking it if it's already marked
					if minValue != kCollision
					{
						mapCodeToErrorCorrectedCode[possibleValueIndex] = kCollision
						mapDistToErrorCorrectedCode[possibleValueIndex] = Int8(distance)
					}
					continue
				}
			}
		}

		// Remove the minDistances from the upper bits of the map codes and replace collisions with `Unassigned`
		for i in 0..<kFullRange
		{
			// Extract the distance and value from the map data
			let value = mapCodeToErrorCorrectedCode[i]

			// At this point, we should no longer have an unassigned value
			assert(value != CardState.Unassigned.rawValue)

			// Collisions get remapped to `Unassigned`
			if value == kCollision
			{
				mapCodeToErrorCorrectedCode[i] = CardState.Unassigned.rawValue
				mapCodeToErrorCorrectedIndex[i] = CardState.Unassigned.rawValue
			}
			// Not a collision, so just store the value
			else
			{
				mapCodeToErrorCorrectedCode[i] = value
			}
		}

		// Ensure we have all actual codes in both maps
		for i in 0..<mapIndexToCode.count
		{
			let code = mapIndexToCode[i]

			assert(mapCodeToErrorCorrectedCode[code] == code)
			assert(mapCodeToErrorCorrectedIndex[code] == i)
		}

		// Calc error correction distance
		var distances = [Int](repeating: 0, count: bitCount)
		for i in 0..<mapCodeToErrorCorrectedCode.count
		{
			let x = mapCodeToErrorCorrectedCode[i]
			if x == CardState.Unassigned.rawValue { continue }
			let d = calcHammingDistance(from: i, to: x)
			distances[d] += 1
		}

		var distancesStr = ""
		for i in 0..<distances.count
		{
			let c = distances[i]
			if c == 0 { continue }
			distancesStr += "\(i)[\(c)] "
		}

		var used = 0
		for value in mapCodeToErrorCorrectedCode
		{
			if value != CardState.Unassigned.rawValue
			{
				used += 1
			}
		}
		let ecRate = Double(used) * 100 / Double(mapCodeToErrorCorrectedCode.count)

		gLogger.always(" > \(formatName): Bits: \(bitCount), Values: \(mapIndexToCode.count), EC Rate: \(String(format: "%.2f", ecRate))%, EC distances: \(distancesStr)")

		return (mapCodeToErrorCorrectedCode, mapCodeToErrorCorrectedIndex)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Histograms
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the set of Hamming Distances in Histogram format between all pairs of codes from the set specified by `codes` of
	/// `codeBits` bits each.
	///
	/// The histogram is an array in which the index is the hamming distance and the array element at an index is the number of code
	/// pairs found to have that distance. For example, if arr[4] contains 128, then there were 128 code pairs that had a Hamming
	/// Distance of 4.
	///
	/// The size of the array will be `codeBits` + 1.
	///
	/// Any code in `codes` that is less than zero will be ignored
	public class func generateDistanceHistogram(for codes: UnsafeMutableArray<Int>, ofBits codeBits: Int) -> UnsafeMutableArray<Int>
	{
		var distanceHistogram = UnsafeMutableArray<Int>(repeating: 0, count: codeBits + 1)

		for i in 0..<codes.count
		{
			let a = codes[i]
			for j in i+1..<codes.count
			{
				let b = codes[j]
				distanceHistogram[HammingDistance.calcHammingDistance(from: a, to: b)] += 1
			}
		}

		return distanceHistogram
	}

	/// Returns a histogram that represents the number of bits set within a set of `codes` of a given `bitCount`
	///
	/// The size of the array will be `bitCount` + 1.
	public class func generateBinaryHistogram(for codes: UnsafeMutableArray<Int>, ofBits bitCount: Int) -> UnsafeMutableArray<Int>
	{
		var binaryHistogram = UnsafeMutableArray<Int>(repeating: 0, count: bitCount + 1)

		for i in 0..<codes.count
		{
			let code = codes[i]
			var bitsUsed = 0
			for i in 0..<bitCount
			{
				if (code >> i) & 1 == 1 { bitsUsed += 1 }
			}
			binaryHistogram[bitsUsed] += 1
		}

		return binaryHistogram
	}

	/// Returns a string representation of a histogram table, which is an ASCII chart with each line being an entry in the histogram
	/// and the data charted with ASCII characters extending horizontally. In addition, each line in the string can be prefixed, which
	/// is useful for indentation.
	public class func generateHistogramTable(histogramData: UnsafeMutableArray<Int>, prefix: String = "") -> String
	{
		// Calculate our histogram
		var histogramTable = ""
		var total = 0
		for i in 0..<histogramData.count
		{
			total += histogramData[i]
		}
		for i in 0..<histogramData.count
		{
			// The count of elements with this hamming distance
			let count = histogramData[i]

			// Calculate this map's value
			let percent = Real(count * 100) / Real(total)
			histogramTable += String(format: "\(prefix)%2d (%4d or %5.2f%%): \(String(repeating: "o", count: Int(percent + 0.5)))\(String.kNewLine)", arguments: [i, count, percent])
		}

		return histogramTable
	}
}
