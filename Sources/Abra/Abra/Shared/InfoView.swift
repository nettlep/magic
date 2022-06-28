//
//  InfoView.swift
//  magic
//
//  Created by Grace Nettle on 10/9/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI
#if os(iOS)
import SeerIOS
import MinionIOS
#else
import Seer
import Minion
#endif

// swiftlint:disable type_name
struct infoHeader: ViewModifier {
	func body(content: Content) -> some View {
		content
			.font(.title2)
			.foregroundColor(.accentColor)
			.lineLimit(1)
			.padding(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
			.minimumScaleFactor(0.01)
			.fixedSize(horizontal: false, vertical: true)
	}
}

struct infoSubheader: ViewModifier {
	func body(content: Content) -> some View {
		content
			.font(.title3)
			.lineLimit(1)
			.foregroundColor(.secondary)
			.padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
			.minimumScaleFactor(0.01)
			.fixedSize(horizontal: false, vertical: true)
	}
}

// swiftlint:disable type_name
struct infoContent: ViewModifier {
	func body(content: Content) -> some View {
		content
			.font(.none)
			.lineLimit(1)
			.minimumScaleFactor(0.01)
			.fixedSize(horizontal: false, vertical: true)
	}
}

struct ConnectionView: View {
	@EnvironmentObject var uiState: UIState

	var body: some View {
		Text("Connection")
			.modifier(infoHeader())

		VStack {
			Text("Server address")
				.modifier(infoSubheader())
			if let serverAddress = uiState.serverAddress {
				Text(uiState.localServerEnabled ? "Local" : "\(serverAddress.toString())")
					.modifier(infoContent())
			} else {
				Text("[not connected]")
					.modifier(infoContent())
			}
		}
	}
}

struct VersionView: View {
	@EnvironmentObject var uiState: UIState

	var body: some View {
		Text("Versions (local)")
			.modifier(infoHeader())

		VStack {
			HStack {
				HStack {
					Spacer()
					Text("Abra").modifier(infoSubheader())
				}
				HStack {
					Text("\(AbraVersion)").modifier(infoContent())
					Spacer()
				}
			}
			HStack {
				HStack {
					Spacer()
					Text("Seer").modifier(infoSubheader())
				}
				HStack {
					Text("\(SeerVersion)").modifier(infoContent())
					Spacer()
				}
			}
			HStack {
				HStack {
					Spacer()
					Text("Minion").modifier(infoSubheader())
				}
				HStack {
					Text("\(MinionVersion)").modifier(infoContent())
					Spacer()
				}
			}
		}

		if let serverVersions = uiState.serverVersions {
			if serverVersions.count > 0 {
				Text("Versions (server)")
					.modifier(infoHeader())

				VStack {
					ForEach(serverVersions.sorted(by: >), id: \.key) { key, value in
						HStack {
							HStack {
								Spacer()
								Text(key).modifier(infoSubheader())
							}
							HStack {
								Text(value).modifier(infoContent())
								Spacer()
							}
						}
					}
				}
			}
		}
	}
}

struct LegalView: View {
	@EnvironmentObject var uiState: UIState

	var body: some View {
		VStack {
			Text("Abra © 2022 Paul Nettle")
			Text("Vectorized Playing Cards 2.0 © 2015 Chris Aguilar")
		}
		.font(.subheadline)
		.foregroundColor(.secondary)
		.lineLimit(1)
		.minimumScaleFactor(0.01)
		.fixedSize(horizontal: false, vertical: true)
	}
}

struct InfoView: View {
	var body: some View {
		VStack {
			ScrollView {
				VStack {
					ConnectionView()
					VersionView()
				}
			}
			.padding()

			LegalView()
		}
		.padding()
		#if os(iOS)
		.navigationBarTitle("Info", displayMode: .inline)
		#endif
	}
}

struct InfoView_Previews: PreviewProvider {
	static var previews: some View {
		InfoView()
			.environmentObject(UIState.shared)
	}
}
