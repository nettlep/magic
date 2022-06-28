//
//  SearchResult.swift
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

/// The result of the deck search
public enum SearchResult
{
	/// The deck was found, but it was too small in frame for decoding
	case TooSmall

	/// No deck was found
	case NotFound

	/// A deck was found, extents were calculated and a MarkLines object is available
	case Decodable(markLines: MarkLines)

	/// Returns the MarkLines for the found deck, if available
	public var markLines: MarkLines?
	{
		if case let .Decodable(markLines) = self
		{
			return markLines
		}
		return nil
	}

	/// Returns true if the result is a .TooSmall result, otherwise false
	public var isTooSmall: Bool
	{
		if case .TooSmall = self { return true }
		return false
	}

	/// Returns true if the result is a .NotFound result, otherwise false
	public var isNotFound: Bool
	{
		if case .NotFound = self { return true }
		return false
	}

	/// Returns true if the deck was found, otherwise false
	public var isFound: Bool
	{
		return !isNotFound
	}

	/// Returns true if the result is a .Decodable result, otherwise false
	public var isDecodable: Bool
	{
		if case .Decodable = self { return true }
		return false
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension SearchResult: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		switch self
		{
			case .TooSmall:
				return "Too small"

			case .NotFound:
				return "Not found"

			case .Decodable:
				return "Decodable"
		}
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Parsable description
// ---------------------------------------------------------------------------------------------------------------------------------

extension SearchResult
{
	/// Returns a string constant useful for reporting and parsing
	public var parsableDescription: String
	{
		return description
	}
}
