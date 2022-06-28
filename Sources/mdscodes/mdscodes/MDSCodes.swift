//
//  MDSCodes.swift
//  MDSCodes
//
//  Created by Paul Nettle on 1/24/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import Seer

// ---------------------------------------------------------------------------------------------------------------------------------
//   ____                           _                __  __       _        _
//  / ___| ___ _ __   ___ _ __ __ _| |_ ___  _ __   |  \/  | __ _| |_ _ __(_)_  __
// | |  _ / _ \ '_ \ / _ \ '__/ _` | __/ _ \| '__|  | |\/| |/ _` | __| '__| \ \/ /
// | |_| |  __/ | | |  __/ | | (_| | || (_) | |     | |  | | (_| | |_| |  | |>  <
//  \____|\___|_| |_|\___|_|  \__,_|\__\___/|_|     |_|  |_|\__,_|\__|_|  |_/_/\_\
//
// ---------------------------------------------------------------------------------------------------------------------------------

internal func generateMDSCodesMatrix(codeBits: Int, dataBits: Int, binaryOptimization: Bool, shuffle: Bool, verbose: Bool)
{
	let parityBits = codeBits - dataBits
	var bestMinimumDistance = 0
	var bestPoly = 0
	var bestCodes = UnsafeMutableArray<Int>()
	var bestMatrix = UnsafeMutableArray<Int>()

	var lastUpdateTimeMS = Date.timeIntervalSinceReferenceDate * 1000.0

	let maxPoly = 1 << (parityBits-1)
	for polyBase in 0..<maxPoly
	{
		// Generate a polynomial value with an additional high and low bit surrounding the original polyBase bits
		let poly = (1 << parityBits+1) | (polyBase << 1) | 1
		var matrix = generateMdsMatrix(codeBits: codeBits, dataBits: dataBits, poly: poly)
		defer { matrix.free() }

		var codes = generateCodes(fromMatrix: matrix, dataBits: dataBits, poly: poly)
		defer { codes.free() }

		let minimumDistance = HammingDistance.calcMinimumDistance(for: codes, codeBits: codeBits, bestMinimumDistance: bestMinimumDistance)
		if minimumDistance > bestMinimumDistance
		{
			bestMinimumDistance = minimumDistance
			bestPoly = poly
			bestMatrix = UnsafeMutableArray<Int>(matrix)
			bestCodes = UnsafeMutableArray<Int>(codes)
		}

		let curUpdateTimeMS = Date.timeIntervalSinceReferenceDate * 1000.0
		if curUpdateTimeMS - lastUpdateTimeMS > 250
		{
			lastUpdateTimeMS = curUpdateTimeMS
			let pct = Int(Double(polyBase+1) / Double(maxPoly) * 100)
			print("\(polyBase+1) of \(maxPoly) (\(pct)%)\r", terminator: "")
		}
	}

	print("                                                    \r", terminator: "")

	if bestMatrix.isEmpty
	{
		print("No valid matrix found")
		return
	}
	if bestCodes.isEmpty
	{
		print("No valid codes found")
		return
	}

	if binaryOptimization
	{
		var optimizedCodes = optimizeBinaryDistribution(codes: bestCodes, codeBits: codeBits)
		defer { optimizedCodes.free() }

		bestCodes.assign(from: optimizedCodes)
	}

	if shuffle
	{
		shuffleArray(&bestCodes)
	}

	dumpMdsData(codes: bestCodes, codeBits: codeBits, type: "Matrix", poly: bestPoly, matrix: bestMatrix, verbose: verbose)
}

// Much of this information comes from:
//
//     http://www.ee.unb.ca/cgi-bin/tervo/polygen2.pl
//
//
// poly is an n-bit value in which n = codeBits - dataSize
func generateMdsMatrix(codeBits: Int, dataBits: Int, poly: Int) -> UnsafeMutableArray<Int>
{
	let p = poly << (dataBits-1)
	var matrix = UnsafeMutableArray<Int>(repeating: 0, count: (codeBits * dataBits))

	for row in 0..<dataBits
	{
		let rval = p >> row

		for i in 0..<codeBits
		{
			let bit = (rval >> (codeBits - i - 1)) & 1
			matrix[row * codeBits + i] = bit
		}
	}

	return matrix
}

func generateCodes(fromMatrix matrix: UnsafeMutableArray<Int>, dataBits: Int, poly: Int) -> UnsafeMutableArray<Int>
{
	let codeBits = matrix.count / dataBits
	assert(codeBits * dataBits == matrix.count)

	let codeCount = 1 << dataBits
	var codes = UnsafeMutableArray<Int>(repeating: 0, count: codeCount)

	for i in 0..<codeCount
	{
		codes[i] = multiply(matrix, dataBits: dataBits, vector: i)
	}

	// XOR all codes against a mask of alternating 1s and 0s to reduce the chances we'll get codes with all zeros or all 1's
	var mask = 0
	for i in 0..<(codeBits/2)
	{
		mask |= 1 << (i*2)
	}
	for i in 0..<codes.count
	{
		codes[i] ^= mask
	}

	return codes
}
// Perform a binary matrix * vector multiplication
//
// The matrix is assumed to be binary (contains only 1s or 0s) and the vector is stored in an integer
func multiply(_ matrix: UnsafeMutableArray<Int>, dataBits: Int, vector: Int) -> Int
{
	let codeBits = matrix.count / dataBits
	assert(codeBits * dataBits == matrix.count)

	var result = 0

	for col in 0..<codeBits
	{
		var bit = 0
		for row in 0..<dataBits
		{
			let vBit = (vector >> row) & 1
			bit += matrix[row*codeBits+col] * vBit
		}

		result = (result << 1) | (bit & 1)
	}

	return result
}

func matrixString(_ matrix: UnsafeMutableArray<Int>, dataBits rows: Int, prefix: String) -> String
{
	let cols = matrix.count / rows
	assert(cols * rows == matrix.count)

	var str = ""
	for row in 0..<rows
	{
		str += prefix
		for col in 0..<cols
		{
			str += "\(matrix[cols * row + col])"
		}
		str += "\n"
	}

	return str
}

// ---------------------------------------------------------------------------------------------------------------------------------
//  ____       _ _           _
// |  _ \ __ _| (_)_ __   __| |_ __ ___  _ __ ___   ___
// | |_) / _` | | | '_ \ / _` | '__/ _ \| '_ ` _ \ / _ \
// |  __/ (_| | | | | | | (_| | | | (_) | | | | | |  __/
// |_|   \__,_|_|_|_| |_|\__,_|_|  \___/|_| |_| |_|\___|
//
// ---------------------------------------------------------------------------------------------------------------------------------

/// Produces a set of codes that are palindrome. The codes produced have a minimum distance of 3, which provides a single bit
/// of error correction.
///
/// It works like this:
///
/// A set of _1 << dataBits_ values is iterated. For a 6-bit code, that would be an iteration over the values [0,63]. A parity bit
/// is then added to each value, producing a value that is (dataBits + 1) bits wide:
///
/// Example value: 0000000101001
/// Parity added:  0000001010011
///
/// The value is then shifted left into the upper portion of the final code. Finally the bits in the value are reversed and ORed
/// with the final code:
/// 
/// Shifted left:  1010011000000
/// Reversed:      0000001100101
///                -------------
/// OR'd result:   1010011100101  <-- Palindrome code
///
/// This produces a code that is `dataBits * 2 + 1` bits wide.
///
/// Finally, a mask of alternating 0s and 1s is XORed onto each code to avoid codes of all 0s or all 1s.
internal func generateMDSCodesPalindrome(dataBits: Int, shuffle: Bool, verbose: Bool)
{
	let codeBits = dataBits * 2 + 1
	var codes = UnsafeMutableArray<Int>(withCapacity: (1<<dataBits))
	defer { codes.free() }

	var mask = 0
	for i in 0..<((dataBits+1)/2)
	{
		mask |= 1 << (i*2)
	}

	for i in 0..<(1<<dataBits)
	{
		var code = (i << 1) | parity(of: i)
		code ^= mask
		code = (code << dataBits) | code.reversedBits(bitCount: (dataBits+1))
		codes.add(code)
	}

	// Verify reversibility
	for i in 0..<codes.count
	{
		let code = codes[i]
		let reversed = code.reversedBits(bitCount: codeBits)
		if code != reversed
		{
			print("ERROR: Reversability test failed! \(code.binaryString()) != \(reversed.binaryString())")
			return
		}
	}

	print("")

	if shuffle
	{
		shuffleArray(&codes)
	}

	dumpMdsData(codes: codes, codeBits: codeBits, type: "Palindrome", verbose: verbose)
}

// ---------------------------------------------------------------------------------------------------------------------------------
//  ____                         _ _     _
// |  _ \ _____   _____ _ __ ___(_) |__ | | ___
// | |_) / _ \ \ / / _ \ '__/ __| | '_ \| |/ _ \
// |  _ <  __/\ V /  __/ |  \__ \ | |_) | |  __/
// |_| \_\___| \_/ \___|_|  |___/_|_.__/|_|\___|
//
// ---------------------------------------------------------------------------------------------------------------------------------

/// Produces a set of codes that are recognizably reversible. That is, when the code is read with the bits in reverse order, that
/// code in recognized as the original code in reverse. This is in contrast to a palindrome code, in which the code reads the same
/// in both directions preventing the ability to recognize when the code has been reversed.
///
/// This produces a code that is `dataBits * 2 + 1` bits wide. The codes produced have a minimum distance of 3, which provides a
/// single bit of error correction.
///
/// Note that the lower limit for `dataBits` is 5. This code has been tested to work with `dataBits` up to 16 bits.
internal func generateMDSCodesReversible(dataBits: Int, shuffle: Bool, verbose: Bool)
{
	if dataBits < 5
	{
		print("ERROR: Reversible codes must have at least 5 bits of data")
		return
	}

	let codeBits = dataBits * 2 + 1
	var codes = UnsafeMutableArray<Int>(withCapacity: (1<<dataBits))
	defer { codes.free() }

	for i in 0..<(1<<dataBits)
	{
		var code = i << (dataBits + 1)
		code |= i << 1
		code |= parity(of: i)
		codes.add(code)
	}

	var mask = 0
	for i in 0..<(codeBits/2)
	{
		mask |= 1 << (i*2)
	}

	// This value found by trial and error
	mask ^= 0b111

	for i in 0..<codes.count
	{
		codes[i] = codes[i] ^ mask
	}

	print("")

	if shuffle
	{
		shuffleArray(&codes)
	}

	dumpMdsData(codes: codes, codeBits: codeBits, type: "Reversible", reversible: true, verbose: verbose)
}

// ---------------------------------------------------------------------------------------------------------------------------------
//   ____                                          ____          _
//  / ___|___  _ __ ___  _ __ ___   ___  _ __     / ___|___   __| | ___
// | |   / _ \| '_ ` _ \| '_ ` _ \ / _ \| '_ \   | |   / _ \ / _` |/ _ \
// | |__| (_) | | | | | | | | | | | (_) | | | |  | |__| (_) | (_| |  __/
//  \____\___/|_| |_| |_|_| |_| |_|\___/|_| |_|   \____\___/ \__,_|\___|
//
// ---------------------------------------------------------------------------------------------------------------------------------

// Returns parity (either a 0 or 1) for the input `value`
func parity(of value: Int) -> Int
{
	var count = 0
	for i in 0..<32
	{
		if ((value >> i) & 1) == 1 { count += 1 }
	}
	return count & 1
}

// Returns an array of `count` shuffled indices
private func shuffleArray(_ array: inout UnsafeMutableArray<Int>)
{
	// We advance through the indices at intervals of prime numbers to ensure we don't advance through evenly divisible chunks
	// of `count` (which could produce a pattern)
	let primes = [7, 11, 13]

	// Iterate through the list a prime number of times
	for i in 0..<array.count * 17
	{
		// Select a pair of indices that are a prime distance from the current index
		let a = (i + primes[(i+0) % primes.count]) % array.count
		let b = (i + primes[(i+1) % primes.count]) % array.count

		// Swap them
		array.swapAt(a, b)
	}
}

/// Optimizes the binary layout of the set of codes such that the codes have the most favorable bit distribution across all codes
///
/// Favorable codes are those with the bit distributions that land in the center of the histogram. In other words, those codes
/// closest to the same number of bits set as unset, across the entire set of codes.
private func optimizeBinaryDistribution(codes: UnsafeMutableArray<Int>, codeBits: Int) -> UnsafeMutableArray<Int>
{
	let codeCount = Int(1) << codeBits

	print("Optimizing...")

	var bestHistString = ""
	var optimizedBestSet = UnsafeMutableArray<Int>(codes)
	var optimizedMaskedSet = UnsafeMutableArray<Int>()
	defer { optimizedMaskedSet.free() }

	/// Try each value as a mask to determine which mask provides the best bit distribution
	for mask in 0..<codeCount-1
	{
		optimizedMaskedSet.assign(from: codes)
		for i in 0..<optimizedMaskedSet.count { optimizedMaskedSet[i] ^= mask }

		var histogram = HammingDistance.generateBinaryHistogram(for: optimizedMaskedSet, ofBits: codeBits)
		defer { histogram.free() }

		// Fold the histogram over upon itself, so first half contains both, the start to the center and the end to the center. We
		// then store this in string format so it can be sorted.
		var histString = ""
		for i in 0..<histogram.count / 2
		{
			histString += (histogram[i] + histogram[histogram.count - i - 1]).toString(5, zero: true)
		}

		// Higher numbers are better for balance
		if bestHistString.isEmpty || histString < bestHistString
		{
			bestHistString = histString
			optimizedBestSet.assign(from: optimizedMaskedSet)
		}
	}

	return optimizedBestSet
}

// ---------------------------------------------------------------------------------------------------------------------------------
// User output
// ---------------------------------------------------------------------------------------------------------------------------------

/// Produces a full diagnostic dump of a set of MDS codes, including the 2D distance map, a histogram and the raw code data.
private func dumpMdsData(codes: UnsafeMutableArray<Int>, codeBits: Int, type: String, reversible: Bool = false, poly: Int? = nil, matrix: UnsafeMutableArray<Int>? = nil, verbose: Bool)
{
	// Indent all of the things!
	let prefix = "      "

	// Calculate our data bits
	var dataBits = 0
	var count = codes.count - 1
	while count > 0
	{
		count >>= 1
		dataBits += 1
	}

	let minimumDistance = HammingDistance.calcMinimumDistance(for: codes, codeBits: codeBits, reversible: reversible)
	let correctable = (minimumDistance - 1) / 2
	let redundancy = Double(correctable) * 100 / Double(codeBits)
	print("Stats")
	print("")
	print(prefix + "Type:             \(type)")
	print(prefix + "Code bits:        \(codeBits)")
	print(prefix + "Data bits:        \(dataBits)")
	print(prefix + "Minimum distance: \(minimumDistance)")
	print(prefix + "Correctable bits: \(correctable)")
	print(prefix + "Redundancy:       \(String(format: "%.2f", redundancy))%")
	print(prefix + "Reversible:       \(reversible ? "true":"false")")
	print("")

	if let matrix = matrix
	{
		var polyString = ""
		if let poly = poly
		{
			polyString = " from polynomial \(poly.binaryString(codeBits - dataBits + 1))"
		}

		print("Matrix (\(matrix.count / dataBits), \(dataBits))\(polyString)")
		print("")
		print(matrixString(matrix, dataBits: dataBits, prefix: prefix))
	}

	print("Codes (integer array)")
	print("")
	print(rawDataString(codes: codes, countPerLine: 10, prefix: prefix))

	print("Codes (binary array)")
	print("")
	print(rawDataString(codes: codes, countPerLine: 5, dumpBoolean: true, bitCount: codeBits, prefix: prefix))

	if verbose
	{
		print("Binary distribution histogram")
		print("")
		var binaryHistogram = HammingDistance.generateBinaryHistogram(for: codes, ofBits: codeBits)
		defer { binaryHistogram.free() }
		print(HammingDistance.generateHistogramTable(histogramData: binaryHistogram, prefix: prefix))

		print("Distance map")
		print("")
		print(HammingDistance.generateHammingDistanceMap(codes: codes, prefix: prefix))
	}
}

/// Returns a string containing `codes` in the format of an array, useful for inclusion in code.
///
/// An optional `countPerLine` can be used to specify the number of elements in the array between line breaks. In addition, each
/// line in the string can be prefixed, which is useful for indentation.
private func rawDataString(codes: UnsafeMutableArray<Int>, countPerLine: Int = 10, dumpBoolean: Bool = false, bitCount: Int = 32, prefix: String = "") -> String
{
	var newLine = countPerLine
	var str = prefix + "[" + String.kNewLine
	str += prefix + "    "
	for i in 0..<codes.count
	{
		if dumpBoolean
		{
			str += codes[i].binaryString(bitCount)
		}
		else
		{
			str += codes[i].toString(6)
		}
		if i >= codes.count - 1
		{
			str += String.kNewLine + prefix + "]" + String.kNewLine
		}
		else
		{
			newLine -= 1
			if newLine == 0
			{
				str += "," + String.kNewLine + prefix + "    "
				newLine += countPerLine
			}
			else
			{
				str += ", "
			}
		}
	}

	return str
}
