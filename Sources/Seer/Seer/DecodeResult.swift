//
//  DecodeResult.swift
//  Seer
//
//  Created by Paul Nettle on 5/25/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// The result of the decode process
public enum DecodeResult
{
	/// A general failure, with a reason message
	case GeneralFailure(reason: String)

	/// The mark lines are not sharp enough for decoding
	case NotSharp

	/// The deck contained too few cards
	case TooFewCards(deck: Deck)

	/// The cards were decoded and a set of card indices is available
	case Decoded(deck: Deck)

	/// Returns true if the result is a .GeneralFailure result, otherwise false
	public var isGeneralFailure: Bool
	{
		if case .GeneralFailure = self { return true }
		return false
	}

	/// Returns true if the result is a .NotSharp result, otherwise false
	public var isNotSharp: Bool
	{
		if case .NotSharp = self { return true }
		return false
	}

	/// Returns true if the result is a .TooFewCards result, otherwise false
	public var isTooFewCards: Bool
	{
		if case .TooFewCards = self { return true }
		return false
	}

	/// Returns true if the result is a .Decoded result, otherwise false
	public var isDecoded: Bool
	{
		if case .Decoded = self { return true }
		return false
	}

	/// Returns list of card indices for the decoded deck, if available
	public var deck: Deck?
	{
		if case let .Decoded(deck) = self
		{
			return deck
		}
		else if case let .TooFewCards(deck) = self
		{
			return deck
		}
		return nil
	}

	/// Returns the reason for a general failure, if available
	public var failureReason: String?
	{
		if case let .GeneralFailure(reason) = self
		{
			return reason
		}
		return nil
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension DecodeResult: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		switch self
		{
			/// A general failure, with a reason message
			case let .GeneralFailure(reason):
				return "GeneralFailure[\(reason)]"

			/// The mark lines are not sharp enough for decoding
			case .NotSharp:
				return "NotSharp"

			/// The deck contained too few cards
			case let .TooFewCards(deck):
				return "TooFew[\(deck.count)]"

			/// The cards were decoded and a set of card indices is available
			case let .Decoded(deck):
				return "Decoded[\(deck.count)]"
		}
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Parsable description
// ---------------------------------------------------------------------------------------------------------------------------------

extension DecodeResult
{
	/// Returns a string constant useful for reporting and parsing
	public var parsableDescription: String
	{
		return description
	}
}
