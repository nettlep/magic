//
//  FannedDeck.swift
//  Abra
//
//  Created by Paul Nettle on 10/4/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI

struct FannedDeck {
	struct FannedRow: Identifiable, Equatable {
		/// Our `id` is a dynamic concatenation of the cards we contain, updated whenever the views are updated
		var id: String = UUID().uuidString

		private var _cards = [Card]()
		var cards: [Card] {
			get {
				return _cards
			}
			set {
				_cards = newValue

				// Update our ID
				var result = "FannedRow."
				for view in _cards {
					result += view.faceCode
				}
				id = result
			}
		}

		// Two `FannedRow` structs are equal if their IDs are equal
		static func == (lhs: FannedDeck.FannedRow, rhs: FannedDeck.FannedRow) -> Bool {
			return lhs.id == rhs.id
		}
	}

	var rows = [FannedRow]()

	var rowCount: Int {
		return rows.count
	}

	var colCount: Int {
		return hasData ? rows[0].cards.count : 0
	}

	var hasData: Bool {
		return rows.count > 0 && rows[0].cards.count > 0
	}

	// Generates the number of rows/columns that meets our rectangle-packing criteria
	static func pack(area: CGSize, count: Int) -> (rows: Int, cols: Int) {
		if count == 0 { return (0, 0) }

		let areaAspect = area.width / area.height
		let exposureAspect = 1 - CardView.kVerticalCornerExposureRatio
		let aspect = areaAspect / Card.kPhysicalAspect * exposureAspect
		var rows = Int(ceil(sqrt(Double(count)) / aspect))
		let cols = count / rows + (count % rows > 0 ? 1 : 0)
		// Now that we have our column count, revisit rows and reduce it as needed
		while cols * (rows - 1) >= count { rows -= 1 }
		return (rows, cols)
	}

	static func layout(cards: [Card], size: CGSize) -> FannedDeck {
		var newRows = [FannedRow]()

		if size != .zero {
			let (rows, cols) = pack(area: size, count: cards.count)

			for row in 0..<rows {
				var newCols = FannedRow()

				for col in 0..<cols
				{
					let index = row * cols + col
					if index < cards.count {
						newCols.cards.append(cards[index])
					}
				}

				newRows.append(newCols)
			}
		}

		return FannedDeck(rows: newRows)
	}
}
