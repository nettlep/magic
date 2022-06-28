//
//  Card.swift
//  Abra
//
//  Created by Paul Nettle on 9/17/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import SwiftUI
#if os(iOS)
import SeerIOS
#else
import Seer
#endif

struct Card: Identifiable
{
	struct State: OptionSet
	{
		let rawValue: Int

		// Missing is a special flag - if it is set, all other flags are ignored
		static let missing  = State(rawValue: 1 << 0)

		// Set if the card is reversed
		static let reversed = State(rawValue: 1 << 1)

		// Set if the card is fragile (that is, not reading with robust confidence)
		static let fragile = State(rawValue: 1 << 2)

		// Dimmed cards (for filtered views)
		static let dimmed = State(rawValue: 1 << 3)
	}

	enum Suit: Int
	{
		case Clubs, Diamonds, Hearts, Spades // Standard cards
		case Color, BlackAndWhite            // Jokers only
		case One, Two                        // Ad cards only

		/// Return the name of the image resource associated to this suit
		var resourceName: String
		{
			switch self
			{
				case .Clubs: return "club"
				case .Diamonds: return "diamond"
				case .Hearts: return "heart"
				case .Spades: return "spade"
				case .Color: return "color"
				case .BlackAndWhite: return "bw"
				case .One: return "1"
				case .Two: return "2"
			}
		}

		/// Return the color of the suit ('black' or 'red') used to build the name of the image resource associated to a card's
		/// face value.
		var resourceColorString: String
		{
			switch self
			{
				case .Clubs, .Spades: return "black"
				case .Diamonds, .Hearts: return "red"
				default: return ""
			}
		}

		static func fromFaceCode(_ faceCode: String, withRank rank: Rank) -> Suit?
		{
			if faceCode.length() < 2 { return nil }

			let lowerFaceCode = faceCode.lowercased()
			switch lowerFaceCode.suffix(1)
			{
				case "1": return rank == .Ad ? .One : .BlackAndWhite
				case "2": return rank == .Ad ? .Two : .Color
				case "c": return .Clubs
				case "d": return .Diamonds
				case "h": return .Hearts
				case "s": return .Spades
				default: return nil
			}
		}
	}

	enum Rank: Int
	{
		case King, Queen, Jack, Ten, Nine, Eight, Seven, Six, Five, Four, Three, Two, Ace, Joker, Ad

		/// Return the name of the image resource associated to this face value
		var resourceName: String
		{
			switch self
			{
				case .King: return "king"
				case .Queen: return "queen"
				case .Jack: return "jack"
				case .Ten: return "10"
				case .Nine: return "9"
				case .Eight: return "8"
				case .Seven: return "7"
				case .Six: return "6"
				case .Five: return "5"
				case .Four: return "4"
				case .Three: return "3"
				case .Two: return "2"
				case .Ace: return "ace"
				case .Joker: return "joker"
				case .Ad: return "ad"
			}
		}

		static func fromFaceCode(_ faceCode: String) -> Rank?
		{
			if faceCode.length() < 1 { return nil }

			let lowerFaceCode = faceCode.lowercased()
			switch lowerFaceCode.prefix(1)
			{
				case "2": return .Two
				case "3": return .Three
				case "4": return .Four
				case "5": return .Five
				case "6": return .Six
				case "7": return .Seven
				case "8": return .Eight
				case "9": return .Nine
				case "t": return .Ten
				case "j": return .Jack
				case "q": return .Queen
				case "k": return .King
				case "a": return .Ace
				case "x": return .Joker
				case "z": return .Ad
				default: return nil
			}
		}
	}

	/// How long (tall) is a card from a standard deck of playing cards (in millimeters)
	///
	/// Cards are actually measured in inches, so this is 3.5 inches converted to millimeters
	private static let kPhysicalLengthMM: CGFloat = 88.9

	/// How wide is a card from a standard deck of playing cards (in mm)
	///
	/// Cards are actually measured in inches, so this is 2.5 inches converted to millimeters
	private static let kPhysicalWidthMM: CGFloat = 63.5

	/// Aspect ratio of a card
	public static let kPhysicalAspect = kPhysicalWidthMM / kPhysicalLengthMM

	private(set) var rank: Rank
	private(set) var suit: Suit
	private(set) var faceCode: String

	public var id: String {
		return "Card." + faceCode + "\(state.rawValue)"
	}

	public var state: State

	init?(faceCode: String, state: State = [])
	{
		let (workingFaceCode, reversed) = DeckFormat.getFaceCodeAndReversed(faceCode)
		if workingFaceCode.length() != 2 { return nil }

		self.faceCode = workingFaceCode
		guard let rank = Rank.fromFaceCode(self.faceCode), let suit = Suit.fromFaceCode(self.faceCode, withRank: rank) else
		{ return nil }

		self.rank = rank
		self.suit = suit
		self.state = state
		if reversed { self.state.insert(.reversed) }
	}

	/// Returns a view representation of this card
	mutating public func createView(simple: Bool = false) -> CardView
	{
		return CardView(card: self, simple: simple)
	}
}
