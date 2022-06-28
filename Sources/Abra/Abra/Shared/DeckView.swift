//
//  DeckView.swift
//  Abra
//
//  Created by Paul Nettle on 9/15/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI

struct AngularRowView: View {
	static let kCurvatureOriginDistance: CGFloat = 3

	let animation: Namespace.ID
	var rowIndex: Int
	var cards: [Card]
	var maxCols: Int
	var width: CGFloat
	var height: CGFloat
	var fullCard: Bool

	func angleInterp(angle: CGFloat, pos: Int, steps: Int) -> Double {
		var stepSize = angle * 2 / Double(steps - 1)
		if steps - 1 <= 0 { stepSize = 0 }
		return Double(pos) * stepSize - angle
	}

	var body: some View {
		let aspect = width / height
		let curvatureOriginDistance = AngularRowView.kCurvatureOriginDistance * aspect
		// Fudge values to shrink the row a smidge to account for the curvature of the deck
		let angle = atan2(width / 2, height * curvatureOriginDistance) * 0.85
		HStack(spacing: 0) {
			ZStack {
				ForEach(Array(cards.enumerated()), id: \.1.id) { (fanPos, card) in
					let isFullCard = fullCard || fanPos >= cards.count - 1
					CardView(animation: animation, card: card, simple: !isFullCard)
						.rotationEffect(
							.radians(
								angleInterp(angle: angle,
											pos: fanPos,
											steps: maxCols)
							), anchor: UnitPoint(x: 0.5, y: curvatureOriginDistance)
						)
				}
			}
			// Fudge values to shrink the row a smidge to account for the curvature of the deck
			.frame(height: height * 0.8)
			// Fudge values to shrink the row a smidge to account for the curvature of the deck
			.offset(y: -height * 0.08)
		}
		.frame(width: width, height: height)
	}
}

struct LinearRowView: View {
	let animation: Namespace.ID
	var rowIndex: Int
	var cards: [Card]
	var maxCols: Int
	var width: CGFloat
	var height: CGFloat
	var fullCard: Bool

	var cardWidth: CGFloat {
		return height * Card.kPhysicalAspect
	}

	var cardSpacing: CGFloat {
		return (width - cardWidth) / CGFloat(maxCols - 1)
	}

	var body: some View {
		HStack(spacing: 0) {
			ForEach(cards) { card in
				let fullCard = fullCard || card.id == cards.last?.id
				HStack(spacing: 0) {
					CardView(animation: animation, card: card, simple: !fullCard)
						.frame(width: cardWidth, height: height)
				}
				.frame(width: cardSpacing, alignment: .leading)
			}
		}
	}
}

struct DeckView: View {
	@EnvironmentObject var uiState: UIState
	@Namespace private var animation
	@Binding var cards: [Card]

	func cardHeight(frameHeight: CGFloat, rows: Int) -> CGFloat {
		let partials = CGFloat(rows - 1) * CardView.kVerticalCornerExposureRatio + 1
		return frameHeight / partials
	}

	var body: some View {
		VStack {
			GeometryReader { geo in
				let w = geo.size.width
				let h = geo.size.height
				if w > 0 && h > 0 {
					let fannedDeck = FannedDeck.layout(cards: cards, size: geo.size)
					let cardHeight = cardHeight(frameHeight: h, rows: fannedDeck.rowCount)
					let rowSpacing = cardHeight * CardView.kVerticalCornerExposureRatio

					VStack(spacing: 0) {
						ForEach(Array(fannedDeck.rows.enumerated()), id: \.1.id) { (rowIndex, row) in
							let isFullCard = rowIndex >= fannedDeck.rows.count - 1
							if uiState.angularLayoutDeck {
								AngularRowView(animation: animation, rowIndex: rowIndex, cards: row.cards, maxCols: fannedDeck.colCount, width: w, height: cardHeight, fullCard: isFullCard)
									.frame(width: w, height: rowSpacing, alignment: .topLeading)
							} else {
								LinearRowView(animation: animation, rowIndex: rowIndex, cards: row.cards, maxCols: fannedDeck.colCount, width: w, height: cardHeight, fullCard: isFullCard)
									.frame(width: w, height: rowSpacing, alignment: .topLeading)
							}
						}
					}
					.frame(width: w, height: 100, alignment: .topLeading)
				}
			}
		}
		.if(!uiState.angularLayoutDeck) {
			$0.padding()
		}
		.cornerRadius(8)
		.onLongPressGesture {
			withAnimation(.easeInOut(duration: 0.15)) {
				uiState.angularLayoutDeck.toggle()
			}
		}
	}
}

struct DeckSpreadView_Previews: PreviewProvider {
	static var previews: some View {
		DeckView(cards: .constant(CardTestData.cards))
			.background(Color.white)
			.preferredColorScheme(.light)
			.environmentObject(UIState.shared)

#if os(iOS)
		DeckView(cards: .constant(CardTestData.cards))
			.background(Color.white)
			.preferredColorScheme(.light)
			.environmentObject(UIState.shared)
			.previewInterfaceOrientation(.landscapeLeft)
#endif
	}
}
