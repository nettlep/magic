//
//  ValidationResult.swift
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

/// The result of validating an AnalysisResult against a known deck order from the test harness
///
/// See `ResultValidator` for more information.
public enum ValidationResult
{
	/// The scan was validated as correct against the known testing deck order
	case Correct

	/// The scan was validated as incorrect against the known testing deck order
	case Incorrect(missingCards: [String], unorderedCards: [String], scannedComparison: [String], knownComparison: [String])

	/// Returns the missing cards from an incorrect scan, or nil
	public var missingCards: [String]?
	{
		switch self
		{
			case let .Incorrect(missingCards, _, _, _):
				return missingCards
			default:
				return nil
		}
	}

	/// Returns the unordered cards from an incorrect scan, or nil
	public var unorderedCards: [String]?
	{
		switch self
		{
			case let .Incorrect(_, unorderedCards, _, _):
				return unorderedCards
			default:
				return nil
		}
	}

	/// Returns the scanned cards portion of the comparison against the known deck order of from an incorrect scan, or nil
	public var scannedComparison: [String]?
	{
		switch self
		{
			case let .Incorrect(_, _, scannedComparison, _):
				return scannedComparison
			default:
				return nil
		}
	}

	/// Returns the known deck order portion of the comparison against the scanned cards from an incorrect scan, or nil
	public var knownComparison: [String]?
	{
		switch self
		{
			case let .Incorrect(_, _, _, knownComparison):
				return knownComparison
			default:
				return nil
		}
	}

	/// Returns true if the result is a .Correct result, otherwise false
	public var isCorrect: Bool
	{
		if case .Correct = self { return true }
		return false
	}

	/// Returns true if the result is an .Incorrect result, otherwise false
	public var isIncorrect: Bool
	{
		if case .Incorrect = self { return true }
		return false
	}
}
