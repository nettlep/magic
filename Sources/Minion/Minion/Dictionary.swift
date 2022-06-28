//
//  Dictionary.swift
//  Minion
//
//  Created by Paul Nettle on 3/24/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// General utilitarian extensions for Dictionary collections
public extension Dictionary where Key: ExpressibleByStringLiteral
{
	/// Returns a copy of the dictionary in which every key has been converted to lower-case
	///
	/// Be aware that as Dictionaries are case-sensitive by default, that it is possible for this process to cause key collisions.
	/// In those cases, the return value will be nil.
	func lowercasedKeys() -> [String: Value]?
	{
		var result = [String: Value]()
		for (key, value) in self
		{
			let lowerKey = String(describing: key).lowercased()
			if result[lowerKey] == nil
			{
				result[lowerKey] = value
			}
			else
			{
				return nil
			}
		}

		return result
	}
}
