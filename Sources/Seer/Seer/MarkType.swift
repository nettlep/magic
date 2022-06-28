//
//  MarkType.swift
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

/// Defines the various types of a MarkDefinition.
///
///    Landmark:   A mark that is used for deck recognition (see DeckSearch)
///    Space:      A space in the definition, used to define gaps in the Code printed on a deck
///    Bit(index): A bit (with an index) used to define the code of a card
public enum MarkType
{
	/// A mark that is used for deck recognition (see DeckSearch)
	///
	/// Landmarks provide an additional benefit. Since their positions are actually located and measured within the image, any
	/// (non-landmark) marks that fall between them can be normalized to within that image-space range. Landmarks, in effect,
	/// reduce the error in bit positions to zero at their boundaries.
	case Landmark

	/// A space (a gap) in the Code printed on the deck
	case Space

	/// A bit (with an index) used to define the code of a card. If a CodeDefinition has a 6-bit code encoded, then that code
	/// can be read from the computed property bitIndex from the various MarkDefinitions.
	///
	/// To retrieve the index, use `bitIndex`. Similarly, to retrieve the bit count, call `bitCount`.
	case Bit(index: Int, count: Int)

	/// Returns true if the instance is a landmark
	public var isLandmark: Bool { return self == .Landmark }

	/// Returns true if the instance is a space
	public var isSpace: Bool { return self == .Space }

	/// Returns true if the instance is a Bit
	public var isBit: Bool
	{
		if case .Bit = self { return true }
		return false
	}

	/// Returns the bit index (0 is lsb) of the bit, if available
	public var bitIndex: Int?
	{
		if case let .Bit(index, _) = self { return index }
		return nil
	}

	/// Returns the count of bits in the definition
	public var bitCount: Int?
	{
		if case let .Bit(_, count) = self { return count }
		return nil
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Equatable
// ---------------------------------------------------------------------------------------------------------------------------------

extension MarkType: Equatable
{
	/// Returns a Boolean value indicating whether two values are equal.
	///
	/// Equality is the inverse of inequality. For any values `a` and `b`,
	/// `a == b` implies that `a != b` is `false`.
	///
	/// - Parameters:
	///   - lhs: A value to compare.
	///   - rhs: Another value to compare.
	public static func == (lhs: MarkType, rhs: MarkType) -> Bool
	{
		switch (lhs, rhs)
		{
			case (.Space, .Space):
				return true
			case (.Landmark, .Landmark):
				return true
			case (.Bit(let idx1, let cnt1), .Bit(let idx2, let cnt2)):
				return idx1 == idx2 && cnt1 == cnt2
			default:
				return false
		}
	}
}
