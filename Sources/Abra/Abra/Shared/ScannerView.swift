//
//  ScannerView.swift
//  Abra
//
//  Created by Paul Nettle on 9/16/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI

struct ControlsView: View {
	@EnvironmentObject var uiState: UIState
	@Binding var cameraListVisible: Bool

	var body: some View {
		VStack {
			HStack {
				NotifyButton()
				ConfidenceGaugeView()
				NdoView(ndo: $uiState.ndo)
			}
			.padding(.top)

			Text(uiState.feedback)
				.lineLimit(1)
				.padding(5)

			ViewportView(cameraListVisible: $cameraListVisible)
				.shadow(color: .black.opacity(0.3), radius: 5, x: 5, y: 5)
		}
	}
}

struct FormatListButton: View {
	@Environment(\.colorScheme) var colorScheme
	@Binding var deckFormatName: String?
	@Binding var formatListVisible: Bool

	var body: some View {
		if let deckFormatName = deckFormatName
		{
			Button(action:
			{
				withAnimation {
					formatListVisible.toggle()
				}
			}, label: {
				Text(deckFormatName)
					.font(.system(size: 20))
					.textFieldStyle(PlainTextFieldStyle())
					.padding(5)
					.frame(minWidth: 180)
					.frame(height: AbraApp.kButtonSize)
					.background(colorScheme == .dark ? Color.darkGray : Color.lightGray)
					.foregroundColor(.primary)
					.cornerRadius(8)
			})
			.buttonStyle(PlainButtonStyle())
			.overlay(
				RoundedRectangle(cornerRadius: 8)
					.stroke(Color.accentColor, lineWidth: AbraApp.kButtonLineWidth)
			)
			.padding(5)
		}
	}
}

struct ServerConfigButton: View {
	@EnvironmentObject var uiState: UIState
	var body: some View {
		NavigationLink(destination: ServerConfigView()) {
			Image(systemName: "switch.2")
				.resizable()
				.modifier(baseButtonStyle(label: EmptyView()))
		}
		.disabled(!uiState.isConnected)
	}
}

struct SettingsButton: View {
	var body: some View {
		NavigationLink(destination: SettingsView()) {
			Image(systemName: "gearshape")
				.resizable()
				.modifier(baseButtonStyle(label: EmptyView()))
		}
	}
}

struct NotifyButton: View {
	@EnvironmentObject var uiState: UIState
	var body: some View {
		Image(systemName: "bell")
			.resizable()
			.modifier(bellActionButton(label: EmptyView(), enabled: uiState.isConnected, action: {
				AbraApp.shared.onSendVibration()
			}))
	}
}

struct NdoView: View {
	@Binding var ndo: Bool

	var body: some View {
		Text("NDO")
			.font(.system(size: 72))
			.bold()
			.minimumScaleFactor(0.01)
			.foregroundColor(ndo ? .black : .primary)
			.opacity(ndo ? 1 : 0.3)
			.modifier(bellActionButton(label: EmptyView(), enabled: ndo, highlighted: ndo))
	}
}

struct ScannerView: View {
	#if os(iOS)
	@Environment(\.verticalSizeClass) var verticalSizeClass
	#endif
	@EnvironmentObject var uiState: UIState
	@Binding var formatListVisible: Bool
	@Binding var cameraListVisible: Bool

	private var isVertialRegular: Bool {
		#if os(iOS)
		return verticalSizeClass == .regular
		#else
		return true
		#endif
	}

	private var showingOverlay: Bool {
		return formatListVisible || cameraListVisible
	}

	var body: some View {
		ZStack {
			VStack(spacing: 0) {
				HStack {
					if uiState.isConnected {
						FormatListButton(deckFormatName: $uiState.deckFormatName, formatListVisible: $formatListVisible)
							.transition(.move(edge: .leading))
					}
					Spacer()
				}
				.padding(.horizontal)

				if isVertialRegular {
					VStack {
						ScanResultsView()
						ControlsView(cameraListVisible: $cameraListVisible)
							.padding([.leading, .trailing])
					}
				} else {
					HStack {
						ScanResultsView()
						ControlsView(cameraListVisible: $cameraListVisible)
							.padding([.leading, .trailing])
					}
				}
			}
			.if(showingOverlay) {
				$0.blur(radius: 2)
			}
			#if os(iOS)
			.navigationBarTitle("Scanner", displayMode: .inline)
			#endif

			Rectangle()
				.fill(Color.primary.opacity(showingOverlay ? 0.5:0))
				.ignoresSafeArea()

			if formatListVisible {
				FormatListView(formatListVisible: $formatListVisible)
			} else if cameraListVisible {
				CameraListView(cameraListVisible: $cameraListVisible)
			}
		}
	}
}

struct ScannerView_Previews: PreviewProvider {
	static var previews: some View {
#if os(iOS)
		ScannerView(formatListVisible: .constant(false), cameraListVisible: .constant(false))
			.background(Color.black)
			.preferredColorScheme(.dark)
			.previewInterfaceOrientation(.landscapeLeft)
			.environmentObject(UIState.shared)
#endif
		ScannerView(formatListVisible: .constant(false), cameraListVisible: .constant(false))
			.background(Color.black)
			.preferredColorScheme(.dark)
			.environmentObject(UIState.shared)
#if os(iOS)
		ScannerView(formatListVisible: .constant(false), cameraListVisible: .constant(false))
			.background(Color.white)
			.preferredColorScheme(.light)
			.previewInterfaceOrientation(.landscapeLeft)
			.environmentObject(UIState.shared)
#endif
		ScannerView(formatListVisible: .constant(false), cameraListVisible: .constant(false))
			.background(Color.white)
			.preferredColorScheme(.light)
			.environmentObject(UIState.shared)

		ScannerView(formatListVisible: .constant(true), cameraListVisible: .constant(false))
			.background(Color.black)
			.preferredColorScheme(.dark)
			.environmentObject(UIState.shared)
		ScannerView(formatListVisible: .constant(true), cameraListVisible: .constant(false))
			.background(Color.white)
			.preferredColorScheme(.light)
			.environmentObject(UIState.shared)
	}
}
