//
//  ScanResultsView.swift
//  Abra
//
//  Created by Paul Nettle on 9/29/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI

struct ScanResultsView: View {
	@EnvironmentObject var uiState: UIState

	var body: some View {
		ZStack {
			PlatformBackgroundView {
				VStack(spacing: 0) {
					if uiState.cards.count > 0 {
						DeckView(cards: $uiState.cards)
					} else {
						Text("No cards found, waiting for scan")
							.padding()
							.padding(.bottom, 5)
							.minimumScaleFactor(0.01)
					}
				}
			}
			.padding()
			.padding(.bottom, 5)

			VStack {
				Spacer()
				HStack {
					Text("\(uiState.cardCount) card\(uiState.cardCount == 1 ? "":"s")")
						.font(.subheadline)
						.lineLimit(1)
						.minimumScaleFactor(0.01)
					Spacer()
				}
			}
			.padding(.leading)
			.opacity(uiState.cardCount > 0 ? 1 : 0)
		}
	}
}

struct ScanResultsView_Previews: PreviewProvider {
	static var previews: some View {
		ScanResultsView()
			.padding()
			.background(Color.black)
			.preferredColorScheme(.dark)
			.environmentObject(UIState.shared)
#if os(iOS)
		ScanResultsView()
			.padding()
			.background(Color.white)
			.preferredColorScheme(.light)
			.previewInterfaceOrientation(.landscapeLeft)
			.environmentObject(UIState.shared)
#endif
	}
}
