//
//  String.swift
//  Minion
//
//  Created by Paul Nettle on 3/22/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// Simplifying methods
public extension String
{
	/// The file line separator for text
	///
	/// Note that this is OS-dependent and as such, only supported OSs are listed causing an error for those OSs that are not
	/// currently supported.
	static let kNewLine: String = "\n"

	/// Returns the length of the string, in terms of the number of Unicode scalars
	func length() -> Int
	{
		return unicodeScalars.count
	}

	/// Returns a new string with all whitespace characters removed from the start and end of the string
	func trim() -> String
	{
		return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
	}

	/// Returns a string with the first character removed
	func firstRemoved() -> String
	{
		return String(self[index(after: startIndex)...])
	}

	/// Returns a string with the last character removed
	func lastRemoved() -> String
	{
		return String(self[..<index(before: endIndex)])
	}

	/// Returns an array of strings delimited by `delimiter`
	func split(on delimiter: String = " ") -> [String]
	{
		return components(separatedBy: delimiter)
	}

	/// Returns a new string with all whitespace characters removed from the start and end of the string
	func trim(_ chars: String) -> String
	{
		return trimmingCharacters(in: CharacterSet(charactersIn: chars))
	}

	/// Returns a new string with `suffix` removed from the end of the string, if it exists
	func trimTrailing(_ suffix: String) -> String
	{
		var result = self
		while result.hasSuffix(suffix)
		{
			let endIndex = result.index(result.endIndex, offsetBy: -suffix.length())
			result = String(self[..<endIndex])
		}
		return result
	}
}

/// Conform to LocalizedError so that strings can be thrown
///
/// Example:
///
///		do
///		{
///			throw "Some error"
///		}
///		catch
///		{
///			gLogger.error(error.localizedDescription)
///		}
extension String: LocalizedError
{
	public var errorDescription: String? { return self }
}

/// Extensions for time-based operations
public extension String
{
	/// Returns a formatted timestamp string
	///
	/// If `date` is provided, it is used to produce the string, otherwise the current time is used
	static func conciseTimestamp(date inDate: Date? = nil) -> String
	{
		let df = DateFormatter()
		df.dateFormat = "yyyy/MM/dd@HH:mm:ss"
		return df.string(from: Date())
	}
}
