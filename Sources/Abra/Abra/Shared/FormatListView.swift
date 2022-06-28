//
//  FormatListView.swift
//  Abra
//
//  Created by Paul Nettle on 10/5/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI
#if os(iOS)
import SeerIOS
#else
import Seer
#endif

struct Format: Identifiable {
	var id: String {
		return name
	}
	var name: String
	var description: String
}

struct FormatListView: View {
	@EnvironmentObject var uiState: UIState
	@Binding var formatListVisible: Bool

	var body: some View {
		let codeDefinitions = CodeDefinition.codeDefinitions.sorted { $0.format.name < $1.format.name }
		GeometryReader { geo in
			ZStack {
				List(0..<codeDefinitions.count) { index in
					let format = codeDefinitions[index].format
					HStack(alignment: .top) {
						VStack(alignment: .leading) {
							Text(format.name)
								.font(.title2)
								.foregroundColor(.primary)
							Text(format.description)
								.font(.subheadline)
								.foregroundColor(.secondary)
						}
						Spacer()
					}
					.padding(8)
					// Must set a color with a nearly-invisible opacity here to pick up taps
					.background(uiState.deckFormatName == format.name ? Color.accentColor : Color.black.opacity(0.01))
					.onTapGesture {
						withAnimation {
							ServerConfig.shared.setCodeDefinition(withName: format.name)
							formatListVisible = false
						}
					}
				}
				.cornerRadius(16)
				.padding()
				.frame(width: geo.size.width * 0.9, height: geo.size.height * 0.9)
				.shadow(color: .black.opacity(0.5), radius: 18, x: 15, y: 15)
				.overlay(
					RoundedRectangle(cornerRadius: 16)
						.stroke(Color.gray, lineWidth: 8)
						.padding()
				)
			}
			.frame(width: geo.size.width, height: geo.size.height)
			// Must set a color with a nearly-invisible opacity here to pick up taps
			.background(Color.black.opacity(0.01))
			.onTapGesture {
				withAnimation {
					formatListVisible = false
				}
			}
		}
		.transition(.move(edge: .bottom))
	}
}

struct FormatListView_Previews: PreviewProvider {
	static var previews: some View {
		FormatListView(formatListVisible: .constant(true))
			.environmentObject(UIState.shared)
	}
}
