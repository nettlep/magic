//
//  CardTestData.swift
//  Abra
//
//  Created by Paul Nettle on 9/15/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import SwiftUI

struct CardTestData {
	static let kFaceCodes =
		["AH", "2H", "3H", "4H", "5H", "6H", "7H", "8H", "9H", "TH", "JH", "QH", "KH",
		 "AC", "2C", "3C", "4C", "5C", "6C", "7C", "8C", "9C", "TC", "JC", "QC", "KC",
		 "KD", "QD", "JD", "TD", "9D", "8D", "7D", "6D", "5D", "4D", "3D", "2D", "AD",
		 "KS", "QS", "JS", "TS", "9S", "8S", "7S", "6S", "5S", "4S", "3S", "2S", "AS",
		 "X1", "X2", "Z1", "Z2"]

	static private var _cards = [Card]()
	static var cards: [Card]
	{
		if _cards.count == 0
		{
			for faceCode in CardTestData.kFaceCodes
			{
				var state: Card.State = []
				if faceCode == "JH" { state.insert(.missing) }
				if faceCode.prefix(1) == "5" { state.insert(.reversed) }
				if faceCode.prefix(1) == "T" || faceCode.prefix(1) == "3" { state.insert(.fragile) }
				_cards.append(Card(faceCode: faceCode, state: state)!)
			}
		}

		return _cards
	}
}
