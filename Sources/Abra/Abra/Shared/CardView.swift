//
//  CardView.swift
//  Abra
//
//  Created by Paul Nettle on 9/13/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI

extension String
{
	func length() -> Int
	{
		return unicodeScalars.count
	}
}

extension CGPoint
{
	@inline(__always) public static func + (left: CGPoint, right: CGPoint) -> CGPoint
	{
		var result = CGPoint(x: left.x, y: left.y)
		result += right
		return result
	}
	@inline(__always) public static func += (left: inout CGPoint, right: CGPoint)
	{
		left.x += right.x
		left.y += right.y
	}
}

struct CardView: View, Identifiable
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The horizontal amount of the card that should remain visible when fanning (this is a ratio of the width of the view)
	public static let kHorizontalCornerExposureRatio: CGFloat = 0.15

	/// The vertical amount of the card that should remain visible when fanning (this is a ratio of the height of the view)
	public static let kVerticalCornerExposureRatio: CGFloat = 0.237

	/// The offset from the side edge of the card to the center of the face value/pip (as a ratio of the total width)
	private static let kCornerOffsetRatioX: CGFloat = 0.08

	private var aspectRatio: CGFloat { Card.kPhysicalAspect }

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Identifiable ID - what makes a `CardView` unique is its ID
	var id: String {
		return "cardView." + card.faceCode
	}

	var animation: Namespace.ID = Namespace().wrappedValue
	@EnvironmentObject var uiState: UIState
	@State var card: Card
	@State var simple: Bool = false

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	var body: some View
	{
		GeometryReader { geo in
			ZStack {
				CardBackgroundView(suit: card.suit, rank: card.rank, innerFaceHorizontalPadding: geo.size.height * aspectRatio * 0.16)
					.frame(width: geo.size.height * aspectRatio, height: geo.size.height)

				HStack(spacing: 0) {
					VStack(spacing: 0) {
						CornerView(suit: card.suit, rank: card.rank, rotated: false)
							.frame(height: geo.size.height * 0.19)
						Spacer()
					}
					.padding(EdgeInsets(top: geo.size.height * 0.04, leading: geo.size.height * aspectRatio * 0.03, bottom: 0, trailing: 0))

					Spacer()

					if !simple {
						VStack(spacing: 0) {
							Spacer()
							CornerView(suit: card.suit, rank: card.rank, rotated: true)
								.frame(height: geo.size.height * 0.19)
						}
						.padding(EdgeInsets(top: 0, leading: 0, bottom: geo.size.height * 0.04, trailing: geo.size.height * aspectRatio * 0.03))
					}
				}

				if !simple {
					HStack(spacing: 0) {
						LeftColumnPips(suit: card.suit, rank: card.rank)
							.frame(width: geo.size.height * aspectRatio * 0.19333, alignment: .trailing)
							.padding(EdgeInsets(top: geo.size.height * 0.08, leading: geo.size.height * aspectRatio * 0.15, bottom: geo.size.height * 0.08, trailing: geo.size.height * aspectRatio * 0.03))

						CenterColumnPips(suit: card.suit, rank: card.rank)
							.frame(width: geo.size.height * aspectRatio * 0.19333, alignment: .trailing)
							.padding(EdgeInsets(top: geo.size.height * 0.08, leading: geo.size.height * aspectRatio * 0.03, bottom: geo.size.height * 0.08, trailing: geo.size.height * aspectRatio * 0.03))

						RightColumnPips(suit: card.suit, rank: card.rank)
							.frame(width: geo.size.height * aspectRatio * 0.19333, alignment: .trailing)
							.padding(EdgeInsets(top: geo.size.height * 0.08, leading: geo.size.height * aspectRatio * 0.03, bottom: geo.size.height * 0.08, trailing: geo.size.height * aspectRatio * 0.15))
					}
				}

				CardStateDecorationView(card: card, cardHeight: geo.size.height)
			}
			.background(Color.white)
			.frame(width: geo.size.height * aspectRatio, height: geo.size.height)
			.cornerRadius(geo.size.height * 0.05)
			.onTapGesture {
				uiState.toggleFlaggedFacecode(card.faceCode)
			}
		}
		.aspectRatio(aspectRatio, contentMode: .fit)
		.matchedGeometryEffect(id: card.faceCode, in: animation)
	}
}

struct RankImageView: View {
	var suit: Card.Suit
	var rank: Card.Rank
	var rotated: Bool

	var body: some View {
		Image(suit.resourceColorString + rank.resourceName)
			.resizable()
			.aspectRatio(contentMode: .fit)
			.rotationEffect(.degrees(rotated ? 180 : 0))
	}
}

struct PipImageView: View {
	var suit: Card.Suit
	var rotated: Bool

	var body: some View {
		Image(suit.resourceName)
			.resizable()
			.aspectRatio(contentMode: .fit)
			.rotationEffect(.degrees(rotated ? 180 : 0))
	}
}

struct CornerView: View {
	var suit: Card.Suit
	var rank: Card.Rank
	var rotated: Bool

	var body: some View {
		VStack(spacing: 0) {
			if rank != .Ad && rank != .Joker {
				if rotated {
					VStack(spacing: 1) {
						PipImageView(suit: suit, rotated: rotated)
						RankImageView(suit: suit, rank: rank, rotated: rotated)
					}
				}
				else {
					VStack(spacing: 1) {
						RankImageView(suit: suit, rank: rank, rotated: rotated)
						PipImageView(suit: suit, rotated: rotated)
					}
				}
			}
		}
	}
}

struct LeftColumnPips: View {
	var suit: Card.Suit
	var rank: Card.Rank

	var body: some View {
		VStack(spacing: 0) {
			switch rank {
			case .Four, .Five:
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: true)
			case .Six, .Seven, .Eight:
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: true)
			case .Nine, .Ten:
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: true)
				Spacer()
				PipImageView(suit: suit, rotated: true)
			default:
				EmptyView()
			}
		}
	}
}

struct CenterColumnPips: View {
	var suit: Card.Suit
	var rank: Card.Rank

	var body: some View {
		VStack(spacing: 0) {
			switch rank {
			case .Ace, .Five, .Nine:
				Spacer()
				PipImageView(suit: suit, rotated: false)
				Spacer()
			case .Two:
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: true)
			case .Three:
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: true)
			case .Seven:
				Spacer()
				PipImageView(suit: suit, rotated: false)
				Spacer()
				Spacer()
				Spacer()
			case .Eight:
				Spacer()
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: true)
				Spacer()
			case .Ten:
				Spacer()
				PipImageView(suit: suit, rotated: false)
				Spacer()
				Spacer()
				PipImageView(suit: suit, rotated: true)
				Spacer()
			default:
				EmptyView()
			}
		}
	}
}

struct RightColumnPips: View {
	var suit: Card.Suit
	var rank: Card.Rank

	var body: some View {
		VStack(spacing: 0) {
			switch rank {
			case .Four, .Five:
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: true)
			case .Six, .Seven, .Eight:
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: true)
			case .Nine, .Ten:
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: false)
				Spacer()
				PipImageView(suit: suit, rotated: true)
				Spacer()
				PipImageView(suit: suit, rotated: true)
			default:
				EmptyView()
			}
		}
	}
}

struct CardBackgroundView: View {
	var suit: Card.Suit
	var rank: Card.Rank
	var innerFaceHorizontalPadding: CGFloat

	var body: some View {
		HStack(spacing: 0) {
			switch rank {
			case .Jack, .Queen, .King:
				Image("face\(rank.resourceName)\(suit.resourceName)")
					.resizable()
					.aspectRatio(contentMode: .fit)
					.padding(EdgeInsets(top: 0, leading: innerFaceHorizontalPadding, bottom: 0, trailing: innerFaceHorizontalPadding))
			case .Joker, .Ad:
				Image("card\(rank.resourceName)\(suit.resourceName)")
					.resizable()
					// Our images have the same aspect as our cards here, so we use .fill here intentionally
					// to ensure the images extend to all. Any aspect error will be negligible.
					.aspectRatio(contentMode: .fill)
			default:
				EmptyView()
			}
		}
	}
}

struct CardStateDecorationView: View {
	@EnvironmentObject var uiState: UIState

	var card: Card
	var cardHeight: CGFloat

	var cornerRadius: CGFloat {
		return cardHeight * 0.05
	}
	var lineWidth: CGFloat {
		return cardHeight * 0.06
	}

	var body: some View {
		let state = card.state
		if state.contains(.missing) {
			Color.red
				.opacity(0.2)
		}
		else
		{
			if state.contains(.reversed) {
				Color.blue
					.opacity(0.3)
			}
			if uiState.robustDisplay && state.contains(.fragile) {
				RoundedRectangle(cornerRadius: cornerRadius)
					.stroke(Color.red, lineWidth: lineWidth)
			}
			if state.contains(.dimmed) {
				Color.black
					.opacity(0.3)
			}
			if uiState.isFacecodeFlagged(card.faceCode) {
				Color.green
					.opacity(0.3)
			}
		}

		RoundedRectangle(cornerRadius: cornerRadius)
			.stroke(Color.black, lineWidth: 2)
	}
}

struct CardView_Previews: PreviewProvider {
	static var previews: some View
	{
//		CardView(card: Card(faceCode: "KC")!)

		Group {
			VStack {
				HStack {
					CardView(card: Card(faceCode: "AH", state: [.missing])!)
					CardView(card: Card(faceCode: "2H", state: [.fragile])!)
					CardView(card: Card(faceCode: "3H", state: [.reversed])!)
					CardView(card: Card(faceCode: "4H", state: [.fragile, .reversed])!)
					CardView(card: Card(faceCode: "5H", state: [.dimmed])!)
				}
				HStack {
					CardView(card: Card(faceCode: "6H")!)
					CardView(card: Card(faceCode: "7H")!)
					CardView(card: Card(faceCode: "8H")!)
					CardView(card: Card(faceCode: "9H")!)
					CardView(card: Card(faceCode: "TH")!)
				}
				HStack {
					CardView(card: Card(faceCode: "JH")!)
					CardView(card: Card(faceCode: "QH")!)
					CardView(card: Card(faceCode: "KH")!)
				}
			}

//			VStack {
//				HStack {
//					CardView(card: Card(faceCode: "AC")!)
//					CardView(card: Card(faceCode: "2C")!)
//					CardView(card: Card(faceCode: "3C")!)
//					CardView(card: Card(faceCode: "4C")!)
//					CardView(card: Card(faceCode: "5C")!)
//				}
//				HStack {
//					CardView(card: Card(faceCode: "6C")!)
//					CardView(card: Card(faceCode: "7C")!)
//					CardView(card: Card(faceCode: "8C")!)
//					CardView(card: Card(faceCode: "9C")!)
//					CardView(card: Card(faceCode: "TC")!)
//				}
//				HStack {
//					CardView(card: Card(faceCode: "JC")!)
//					CardView(card: Card(faceCode: "QC")!)
//					CardView(card: Card(faceCode: "KC")!)
//				}
//			}
//
//			VStack {
//				HStack {
//					CardView(card: Card(faceCode: "AD")!)
//					CardView(card: Card(faceCode: "2D")!)
//					CardView(card: Card(faceCode: "3D")!)
//					CardView(card: Card(faceCode: "4D")!)
//					CardView(card: Card(faceCode: "5D")!)
//				}
//				HStack {
//					CardView(card: Card(faceCode: "6D")!)
//					CardView(card: Card(faceCode: "7D")!)
//					CardView(card: Card(faceCode: "8D")!)
//					CardView(card: Card(faceCode: "9D")!)
//					CardView(card: Card(faceCode: "TD")!)
//				}
//				HStack {
//					CardView(card: Card(faceCode: "JD")!)
//					CardView(card: Card(faceCode: "QD")!)
//					CardView(card: Card(faceCode: "KD")!)
//				}
//			}
//
//			VStack {
//				HStack {
//					CardView(card: Card(faceCode: "AS")!)
//					CardView(card: Card(faceCode: "2S")!)
//					CardView(card: Card(faceCode: "3S")!)
//					CardView(card: Card(faceCode: "4S")!)
//					CardView(card: Card(faceCode: "5S")!)
//				}
//				HStack {
//					CardView(card: Card(faceCode: "6S")!)
//					CardView(card: Card(faceCode: "7S")!)
//					CardView(card: Card(faceCode: "8S")!)
//					CardView(card: Card(faceCode: "9S")!)
//					CardView(card: Card(faceCode: "TS")!)
//				}
//				HStack {
//					CardView(card: Card(faceCode: "JS")!)
//					CardView(card: Card(faceCode: "QS")!)
//					CardView(card: Card(faceCode: "KS")!)
//				}
//			}
//
//			HStack {
//				CardView(card: Card(faceCode: "X1", state: [])!)
//				CardView(card: Card(faceCode: "X2", state: [.fragile])!)
//				CardView(card: Card(faceCode: "Z1", state: [.missing])!)
//				CardView(card: Card(faceCode: "Z2", state: [.reversed])!)
//			}
		}
		.environmentObject(UIState.shared)
	}
}
