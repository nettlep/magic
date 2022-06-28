//
//  DeckFormat.swift
//  Seer
//
//  Created by Paul Nettle on 3/15/17.
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

/// Defines a protocol for classes to manage the specifics that link a given deck to the underlying CodeDefinition for the deck
public class DeckFormat
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Definition of a mark, as defined in JSON
	private struct MarkDefinitionJson
	{
		/// Mark type as a string
		enum MarkTypeJson: String
		{
			case Landmark, Space, Bit
		}

		/// The mark type
		let type: MarkTypeJson

		// The width of the mark, in millimeters
		let widthMM: Real

		/// Initialize from a JSON dictionary
		init?(json: [String: Any])
		{
			guard let typeString = json["type"] as? String else
			{
				gLogger.error("Failed to extract key 'type' for deserialization of MarkDefinitionJson")
				return nil
			}
			guard let widthMM = json["widthMM"] as? Double else
			{
				gLogger.error("Failed to extract key 'widthMM' for deserialization of MarkDefinitionJson")
				return nil
			}

			guard let type = MarkTypeJson(rawValue: typeString) else
			{
				gLogger.error("Failed to deserialize deck format mark type for raw value: \(typeString)")
				return nil
			}

			self.type = type
			self.widthMM = Real(widthMM)
		}
	}

	public enum CodeType: String
	{
		case normal

		/// The code is a palindrome code (that is, reads the same in both directions.)
		///
		/// This is not the same as `reversible` codes, which read as different codes in each direction.
		case palindrome

		/// The code is reversible (i.e., can be read backwards or forwards with no error correction collisions)
		///
		/// This is not the same as `palindrome` codes, which read as the same code in each direction. The advantage of a reversible
		/// code is that when read in reverse, the software knows that the card is reversed.
		case reversible

		public var isNormal: Bool
		{
			if case .normal = self { return true }
			return false
		}

		public var isPalindrome: Bool
		{
			if case .palindrome = self { return true }
			return false
		}

		public var isReversible: Bool
		{
			if case .reversible = self { return true }
			return false
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// JSON properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns a unique identifier assigned to this DeckFormat
	private(set) public var id: UInt32

	/// Returns the official name for this format, use this in the config file as the value for `search.CodeDefinition`
	private(set) public var name: String

	/// Returns the description for this format
	private(set) public var description: String

	/// Returns the type of code
	private(set) public var type: CodeType

	/// Returns true if the deck uses inverted luma (for example, with UV-reactive ink marks instead of black ink)
	///
	/// If not set, the default value is `false`
	private(set) public var invertLuma: Bool = false

	/// The length of the longest edge of a card, in millimeters
	private(set) public var physicalLengthMM: Real

	/// The length of the shortest edge of a card, in millimeters
	private(set) public var physicalWidthMM: Real

	/// How wide is a card is (in millimeters)
	private(set) public var printableMaxWidthMM: Real

	/// Returns the physical height (in millimeters) for a full deck of cards, taking into account the number of cards
	/// supported by this DeckFormat. This deck is not compressed (see physicalCompressedStackHeightMM for a compressed height.)
	private(set) public var physicalStackHeightMM: Real

	/// Returns the physical height (in millimeters) for a full deck of cards, taking into account the number of cards
	/// supported by this DeckFormat. This deck is tightly compressed (see physicalStackHeightMM for a general height.)
	private(set) public var physicalCompressedStackHeightMM: Real

	/// Returns the minimum number of cards required for decoding this deck
	private(set) public var minCardCount: Int

	/// Returns an array which can be indexed by Card Index to return a Card Code
	private(set) public var cardCodesNdo: [Int]

	/// Returns an array which can be indexed by Card Index to return a Face Code
	private(set) public var faceCodesNdo: [String]

	/// Returns the test deck order for videos and images using this Code
	private(set) public var faceCodesTestDeckOrder: [String]

	// -----------------------------------------------------------------------------------------------------------------------------
	// General properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the number of bits that represent a Card Code
	private(set) public var cardCodeBitCount: Int

	/// Returns the maximum number of cards a deck of this type can contain
	private(set) public var maxCardCount: Int

	/// Returns the maximum number of cards a deck of this type can contain, including reversed cards
	public var maxCardCountWithReversed: Int
	{
		return reversible ? maxCardCount * 2 : maxCardCount
	}

	// Returns true for reversible code types
	public var reversible: Bool
	{
		return type.isReversible
	}

	/// Stores the mapping of a Card Index (key) to Card Code (forward codes)
	private(set) public var mapIndexToCode: [Int]

	/// Stores the mapping of a Card Code to Card Index
	private(set) public var mapCodeToIndex: [Int]

	/// Stores the mapping of a Face Code (key) to Card Index (value)
	private(set) public var mapFaceCodeToIndex: [String: Int]

	/// Stores the mapping of (potentially invalid) Raw Card Codes to error-corrected Card Codes using a maximum Hamming Distance
	/// calculated by `HammingDistance.calcErrorCorrectedMaps`.
	private(set) public var mapCodeToErrorCorrectedCode = [Int]()

	/// Stores the mapping of (potentially invalid) Raw Card Codes to Card Indices using error correction on the input Raw Card
	/// Code using a maximum Hamming Distance calculated by `HammingDistance.calcErrorCorrectedMaps`.
	private(set) public var mapCodeToErrorCorrectedIndex = [Int]()

	/// Our mark definitions, as read in via JSON
	private var jsonMarkDefinitions = [MarkDefinitionJson]()

	/// Initialize a `DeckFormat` from a JSON dictionary
	public init?(json: [String: Any], fastLoad: Bool = false)
	{
		guard let id = json["id"] as? Int else
		{
			gLogger.error("Failed to extract key 'id' for deserialization of DeckFormatEntry")
			return nil
		}
		guard let name = json["name"] as? String else
		{
			gLogger.error("Failed to extract key 'name' for deserialization of DeckFormatEntry")
			return nil
		}
		guard let description = json["description"] as? String else
		{
			gLogger.error("\(name): Failed to extract key 'description' for deserialization of DeckFormatEntry")
			return nil
		}
		guard let physicalLengthMM = json["physicalLengthMM"] as? Double else
		{
			gLogger.error("\(name): Failed to extract key 'physicalLengthMM' for deserialization of DeckFormatEntry")
			return nil
		}
		guard let physicalWidthMM = json["physicalWidthMM"] as? Double else
		{
			gLogger.error("\(name): Failed to extract key 'physicalWidthMM' for deserialization of DeckFormatEntry")
			return nil
		}
		guard let printableMaxWidthMM = json["printableMaxWidthMM"] as? Double else
		{
			gLogger.error("\(name): Failed to extract key 'printableMaxWidthMM' for deserialization of DeckFormatEntry")
			return nil
		}
		guard let physicalStackHeight52CardsMM = json["physicalStackHeight52CardsMM"] as? Double else
		{
			gLogger.error("\(name): Failed to extract key 'physicalStackHeight52CardsMM' for deserialization of DeckFormatEntry")
			return nil
		}
		guard let physicalCompressedStackHeight52CardsMM = json["physicalCompressedStackHeight52CardsMM"] as? Double else
		{
			gLogger.error("\(name): Failed to extract key 'physicalCompressedStackHeight52CardsMM' for deserialization of DeckFormatEntry")
			return nil
		}
		guard let minCardCount = json["minCardCount"] as? Int else
		{
			gLogger.error("\(name): Failed to extract key 'minCardCount' for deserialization of DeckFormatEntry")
			return nil
		}
		guard var cardCodesNdo = json["cardCodesNdo"] as? [Int] else
		{
			gLogger.error("\(name): Failed to extract key 'cardCodesNdo' for deserialization of DeckFormatEntry")
			return nil
		}
		guard let faceCodesNdo = json["faceCodesNdo"] as? [String] else
		{
			gLogger.error("\(name): Failed to extract key 'faceCodesNdo' for deserialization of DeckFormatEntry")
			return nil
		}
		guard let faceCodesTestDeckOrder = json["faceCodesTestDeckOrder"] as? [String] else
		{
			gLogger.error("\(name): Failed to extract key 'faceCodesTestDeckOrder' for deserialization of DeckFormatEntry")
			return nil
		}
		guard let marks = json["marks"] as? [[String: Any]] else
		{
			gLogger.error("\(name): Failed to extract key 'marks' for deserialization of DeckFormatEntry")
			return nil
		}

		guard let typeString = json["type"] as? String else
		{
			gLogger.error("\(name): Failed to extract key 'type' for deserialization of DeckFormatEntry")
			return nil
		}

		guard let type = CodeType(rawValue: typeString.lowercased()) else
		{
			gLogger.error("\(name): Failed to deserialize deck format type for raw value: \(typeString)")
			return nil
		}

		if let invertLuma = json["invertLuma"] as? Bool
		{
			self.invertLuma = invertLuma
		}

		// Collect our marks (and count the bits along the way)
		self.cardCodeBitCount = 0
		for mark in marks
		{
			guard let mark = MarkDefinitionJson(json: mark) else
			{
				gLogger.error("\(name): Failed to deserialize deck format entry for mark")
				return nil
			}

			if mark.type == .Bit
			{
				self.cardCodeBitCount += 1
			}

			jsonMarkDefinitions.append(mark)
		}

		// Validate the number of cards is the same across all related arrays
		if faceCodesNdo.count != faceCodesTestDeckOrder.count
		{
			gLogger.error("\(name): Card counts do not match between faceCodesNdo and faceCodesTestDeckOrder")
			return nil
		}
		if cardCodesNdo.count < faceCodesNdo.count
		{
			gLogger.error("\(name): Not enough cardCodesNdo codes provided")
			return nil
		}

		// If there are too many card codes, remove the extras
		if cardCodesNdo.count > faceCodesNdo.count
		{
			cardCodesNdo.removeLast(cardCodesNdo.count - faceCodesNdo.count)
		}

		// Set the max card count
		self.maxCardCount = cardCodesNdo.count

		// Set the remaining properties
		self.id = UInt32(id)
		self.name = name
		self.description = description
		self.type = type
		self.physicalLengthMM = Real(physicalLengthMM)
		self.physicalWidthMM = Real(physicalWidthMM)
		self.printableMaxWidthMM = Real(printableMaxWidthMM)
		self.physicalStackHeightMM = Real(physicalStackHeight52CardsMM) * Real(maxCardCount) / 52.0
		self.physicalCompressedStackHeightMM = Real(physicalCompressedStackHeight52CardsMM) * Real(maxCardCount) / 52.0
		self.minCardCount = minCardCount
		self.cardCodesNdo = cardCodesNdo
		self.faceCodesNdo = faceCodesNdo
		self.faceCodesTestDeckOrder = faceCodesTestDeckOrder

		// Allocate our maps
		mapIndexToCode = [Int](repeating: -1, count: maxCardCount + (self.type.isReversible ? maxCardCount : 0))
		mapCodeToIndex = [Int](repeating: -1, count: 1 << cardCodeBitCount)
		mapFaceCodeToIndex = [String: Int]()

		// If we're reversed, extend our faceCodesNdo to account for the additional indices
		if self.type.isReversible
		{
			self.faceCodesNdo.append(contentsOf: faceCodesNdo)
		}

		for cardIndex in 0..<maxCardCount
		{
			let faceCode = faceCodesNdo[cardIndex]
			let cardCodeForward = cardCodesNdo[cardIndex]
			mapIndexToCode[cardIndex] = cardCodeForward
			mapCodeToIndex[cardCodeForward] = cardIndex
			mapFaceCodeToIndex[faceCode] = cardIndex

			if self.type.isReversible
			{
				let cardCodeReversed = cardCodeForward.reversedBits(bitCount: cardCodeBitCount)
				let cardIndexReversed = cardIndex + maxCardCount
				let cardFaceCodeReversed = "(\(faceCode))"
				mapIndexToCode[cardIndexReversed] = cardCodeReversed
				mapCodeToIndex[cardCodeReversed] = cardIndexReversed
				mapFaceCodeToIndex[cardFaceCodeReversed] = cardIndexReversed
				self.faceCodesNdo[cardIndexReversed] = cardFaceCodeReversed
			}
		}

		// Prepare for decoede on load? This saves time later at the expense of load times. Otherwise, the preparation happens
		// on first decode
		if !fastLoad && !prepareForDecode() { return nil }
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// General implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Prepares a DeckFormat for decoding.
	///
	/// This calculates the error correction maps and caches them in memory. It is safe to call this before each attempt to decode a deck using this DeckFormat.
	public func prepareForDecode() -> Bool
	{
		// If we've already calculated our error correction maps, don't do it again
		if mapCodeToErrorCorrectedCode.count != 0 && mapCodeToErrorCorrectedIndex.count != 0
		{
			return true
		}

		// Calculate our error correction maps
		(mapCodeToErrorCorrectedCode, mapCodeToErrorCorrectedIndex) = HammingDistance.calcErrorCorrectedMaps(formatName: name, bitCount: cardCodeBitCount, mapIndexToCode: mapIndexToCode)

		// Verify reversible/palindrome codes have marks that are also palindromes
		let palendromeLayout = isPalendromeLayout(markDefinitions: jsonMarkDefinitions)
		if (self.type.isReversible || self.type.isPalindrome) && !palendromeLayout
		{
			gLogger.error("\(name): Code is defined as palindrome or reversible, but the landmarks/layout is not a palindrome")
			return false
		}
		else if (!self.type.isReversible && !self.type.isPalindrome) && palendromeLayout
		{
			gLogger.error("\(name): Code is defined as non-palindrome and non-reversible, but the landmarks/layout is a palindrome. This can prevent properly oriented scanning.")
			return false
		}

		return true
	}

	public func populateCodeDefinition(_ codeDefinition: CodeDefinition)
	{
		var bitsProcessed = 0
		for mark in jsonMarkDefinitions
		{
			switch mark.type
			{
				case .Landmark:
					codeDefinition.addMarkDefinition(type: .Landmark, widthMM: mark.widthMM)
				case .Space:
					codeDefinition.addMarkDefinition(type: .Space, widthMM: mark.widthMM)
				case .Bit:
					codeDefinition.addMarkDefinition(type: .Bit(index: bitsProcessed, count: cardCodeBitCount), widthMM: mark.widthMM)
					bitsProcessed += 1
			}
		}

		codeDefinition.finalize()
	}

	/// Returns a Card Index from a given a Face Code, if a mapping exists
	public func getCardIndex(fromFaceCode faceCode: String) -> Int?
	{
		return mapFaceCodeToIndex[faceCode]
	}

	/// Returns the array of final card indices to an array of Face Codes
	///
	/// If `reversed` is true, this method will return reversed face codes. Otherwise, this method will ignore reversed cards and
	/// return the face code for the card in non-reversed format. For face codes with reversed cards.
	public func getFaceCodes(indices: [UInt8], reversed: Bool = false) -> [String]
	{
		var faceCodes = [String]()
		faceCodes.reserveCapacity(indices.count)

		if reversed
		{
			for index in indices
			{
				var idx = Int(index)
				if idx >= maxCardCount
				{
					idx -= maxCardCount
					faceCodes.append(idx < 0 ? "--" : idx > faceCodesNdo.count ? "--" : "(\(faceCodesNdo[idx]))")
				}
				else
				{
					faceCodes.append(idx < 0 ? "--" : idx > faceCodesNdo.count ? "--" : faceCodesNdo[idx])
				}

			}
		}
		else
		{
			for index in indices
			{
				var idx = Int(index)
				if idx >= maxCardCount
				{
					idx -= maxCardCount
				}
				faceCodes.append(idx < 0 ? "--" : idx > faceCodesNdo.count ? "--" : faceCodesNdo[idx])
			}
		}

		return faceCodes
	}

	// Returns the base card index, converting reversed cards to non-reversed cards if necessary
	public func getBaseCardIndex(_ cardIndex: UInt8) -> UInt8
	{
		if reversible && cardIndex >= UInt8(maxCardCount) { return cardIndex - UInt8(maxCardCount) }
		return cardIndex
	}

	static public func getFaceCodeAndReversed(_ faceCode: String) -> (faceCode: String, reversed: Bool)
	{
		if faceCode.length() == 2 { return (faceCode, false) }
		return (faceCode.firstRemoved().lastRemoved(), true)
	}

	/// Returns the minimum number of samples to occupy the deck height, given a deck of `cardCount` cards
	///
	/// If the card count is not specified, the calculation will default to the maximum potential cards in a deck's format.
	public func getMinSampleHeight(forCardCount cardCount: Int = -1) -> Real
	{
		let count = cardCount == -1 ? maxCardCount : cardCount
		return Real(count) * Config.deckMinSamplesPerCard
	}

	private func isPalendromeLayout(markDefinitions: [MarkDefinitionJson]) -> Bool
	{
		for i in 0..<markDefinitions.count / 2
		{
			let a = markDefinitions[i]
			let b = markDefinitions[jsonMarkDefinitions.count - i - 1]
			if a.type != b.type || a.widthMM != b.widthMM
			{
				return false
			}
		}

		return true
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Debug
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Dumps a HammingDistance histogram to the log
	public func logHammingDistanceHistogram(prefix: String = "")
	{
		var codes = UnsafeMutableArray<Int>(withArray: cardCodesNdo)
		var hist = HammingDistance.generateDistanceHistogram(for: codes, ofBits: cardCodeBitCount)
		gLogger.info(HammingDistance.generateHistogramTable(histogramData: hist, prefix: prefix))

		hist.free()
		codes.free()
	}

	/// Dumps a binary distribution histogram to the log
	public func logHammingBinaryHistogram(prefix: String = "")
	{
		var codes = UnsafeMutableArray<Int>(withArray: cardCodesNdo)
		var hist = HammingDistance.generateBinaryHistogram(for: codes, ofBits: cardCodeBitCount)
		gLogger.info(HammingDistance.generateHistogramTable(histogramData: hist, prefix: prefix))

		hist.free()
		codes.free()
	}

	/// Dumps a HammingDistance map to the log
	public func logHammingDistanceMap(prefix: String = "")
	{
		var codes = UnsafeMutableArray<Int>(withArray: cardCodesNdo)
		gLogger.info(HammingDistance.generateHammingDistanceMap(codes: codes, prefix: prefix))
		codes.free()
	}

	/// Dumps a full suite of data regarding Hamming Distances to the log
	public func logHammingDistanceInfo()
	{
		gLogger.info("")
		gLogger.info("Hamming distance histogram for \(name):")
		gLogger.info("")
		logHammingDistanceHistogram(prefix: "    ")

		gLogger.info("")
		gLogger.info("Binary distribution histogram for \(name):")
		gLogger.info("")
		logHammingBinaryHistogram(prefix: "    ")

		gLogger.info("")
		gLogger.info("Hamming distance map for \(name):")
		gLogger.info("")
		logHammingDistanceMap(prefix: "    ")
		gLogger.info("")
	}
}

extension DeckFormat: Equatable
{
	public static func == (lhs: DeckFormat, rhs: DeckFormat) -> Bool
	{
		return lhs.name == rhs.name
	}
}
