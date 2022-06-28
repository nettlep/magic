//
//  MenuView.swift
//  Abra
//
//  Created by Paul Nettle on 11/8/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI

struct MenuView: View {
	@EnvironmentObject var uiState: UIState

	@State var formatListVisible: Bool = false
	@State var cameraListVisible: Bool = false
	@State private var selectedView: Int? = 1

	var body: some View {
		NavigationView {
			List {
				NavigationLink(destination: ScannerView(formatListVisible: $formatListVisible, cameraListVisible: $cameraListVisible), tag: 1, selection: self.$selectedView) {
					Text("Scanner")
				}
				NavigationLink(destination: ServerConfigView(), tag: 2, selection: self.$selectedView) {
					Text("Server settings")
				}
				.disabled(!uiState.isConnected)

				NavigationLink(destination: SettingsView(), tag: 3, selection: self.$selectedView) {
					Text("Local settings")
				}
				NavigationLink(destination: LogView(data: AbraLogDevice.logData), tag: 4, selection: self.$selectedView) {
					Text("Log")
				}
				NavigationLink(destination: InfoView(), tag: 5, selection: self.$selectedView) {
					Text("Info")
				}
			}
			.padding(EdgeInsets(top: 8, leading: 3, bottom: 8, trailing: 3))
			#if os(iOS)
			.navigationBarTitle("Menu", displayMode: .inline)
			#endif

			ScannerView(formatListVisible: $formatListVisible, cameraListVisible: $cameraListVisible)
		}
	}
}

struct MenuView_Previews: PreviewProvider {
	static var previews: some View {
#if os(iOS)
		MenuView()
			.background(Color.black)
			.preferredColorScheme(.dark)
			.previewInterfaceOrientation(.landscapeLeft)
			.environmentObject(UIState.shared)
#endif
		MenuView()
			.background(Color.black)
			.preferredColorScheme(.dark)
			.environmentObject(UIState.shared)
#if os(iOS)
		MenuView()
			.background(Color.white)
			.preferredColorScheme(.light)
			.previewInterfaceOrientation(.landscapeLeft)
			.environmentObject(UIState.shared)
#endif
		MenuView()
			.background(Color.white)
			.preferredColorScheme(.light)
			.environmentObject(UIState.shared)

		MenuView(formatListVisible: true)
			.background(Color.black)
			.preferredColorScheme(.dark)
			.environmentObject(UIState.shared)
		MenuView(formatListVisible: true)
			.background(Color.white)
			.preferredColorScheme(.light)
			.environmentObject(UIState.shared)
	}
}
