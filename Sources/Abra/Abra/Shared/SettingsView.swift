//
//  SettingsView.swift
//  magic
//
//  Created by Paul Nettle on 10/8/21.
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

// swiftlint:disable type_name
struct settingsHeader: ViewModifier {
	@State var label: String = ""

	func body(content: Content) -> some View {
		HStack {
			VStack(alignment: .leading, spacing: 0) {
				content
					.padding(.horizontal, 5)
				if label.length() > 0 {
					Text(label)
						.font(.subheadline)
						.foregroundColor(.darkGray)
						.padding(.horizontal, 5)
				}
			}
			.padding(5)
			.foregroundColor(Color.black)

			Spacer()
		}
		.background(Color.lightGray)
	}
}

struct InfoButton: View {
	var body: some View {
		let label =
			VStack(alignment: .leading) {
				Text("Info")
					.font(.headline)
				Text("Application and connection information")
					.foregroundColor(.secondary)
					.font(.subheadline)
			}

		ZStack {
			NavigationLink(destination: InfoView()) {
				Color.clear
			}
			HStack {
				Image(systemName: "info")
					.resizable()
					.modifier(baseButtonStyle(label: label))
				Spacer()
			}
		}
	}
}

struct ResetTrickButton: View {
	@EnvironmentObject var uiState: UIState

	var body: some View {
		let label =
			VStack(alignment: .leading) {
				Text("Reset")
					.font(.headline)
				Text("Reset all cards and results displayed")
					.foregroundColor(.secondary)
					.font(.subheadline)
			}

		Image(systemName: "xmark.bin")
			.resizable()
			.modifier(bounceActionButton(label: label, action: { uiState.resetTrickState() }))
	}
}

struct LocalServerButton: View {
	var withLabel: Bool = true
	@Binding var localServerEnabled: Bool

	var body: some View {
		let label: AnyView = !withLabel ? AnyView(EmptyView()) :
			AnyView(VStack(alignment: .leading) {
				Text("Local server")
					.font(.headline)
				Text("Enable a local server using the camera. Useful when no remote devices are present")
					.foregroundColor(.secondary)
					.font(.subheadline)
			})

		Image(systemName: "viewfinder")
			.resizable()
			.modifier(bounceActionButton(label: label, highlighted: localServerEnabled, action: {
				withAnimation {
					localServerEnabled.toggle()
					Preferences.shared.localServerEnabled = localServerEnabled
					AbraApp.shared.onServerTypeUpdated()
				}
			}))
	}
}

struct AdvertiseServerButton: View {
	var withLabel: Bool = true
	@Binding var advertiseServer: Bool

	var body: some View {
		let label: AnyView = !withLabel ? AnyView(EmptyView()) :
			AnyView(VStack(alignment: .leading) {
				Text("Advertise server")
					.font(.headline)
				Text("Advertise local server so other apps/devices can connect to it (requires WiFi)")
					.foregroundColor(.secondary)
					.font(.subheadline)
			})

		Image(systemName: "antenna.radiowaves.left.and.right")
			.resizable()
			.modifier(bounceActionButton(label: label, highlighted: advertiseServer, action: {
				advertiseServer.toggle()
				Preferences.shared.advertiseServer = advertiseServer
				AbraApp.shared.onServerTypeUpdated()
			}))
	}
}

struct AutoPauseButton: View {
	@Binding var autoPauseEnabled: Bool

	var body: some View {
		let label =
			VStack(alignment: .leading) {
				Text("Auto-pause")
					.font(.headline)
				Text("Automatically pause scanning on the first confident result")
					.foregroundColor(.secondary)
					.font(.subheadline)
			}

		Image(systemName: "playpause.fill")
			.resizable()
			.modifier(bounceActionButton(label: label, highlighted: autoPauseEnabled, action: {
				autoPauseEnabled.toggle()
			}))
	}
}

struct LogButton: View {
	var body: some View {
		let label =
			VStack(alignment: .leading) {
				Text("Application log")
					.font(.headline)
				Text("View the application log output")
					.foregroundColor(.secondary)
					.font(.subheadline)
			}

		ZStack {
			NavigationLink(destination: LogView(data: AbraLogDevice.logData)) {
				Color.clear
			}
			HStack {
				Image(systemName: "scroll")
					.resizable()
					.modifier(baseButtonStyle(label: label))
				Spacer()
			}
		}
	}
}

struct ShutdownButton: View {
	@EnvironmentObject var uiState: UIState

	var body: some View {
		let label =
			VStack(alignment: .leading) {
				Text("Shutdown")
					.font(.headline)
				Text("Sends a request to all remote devices to shut down")
					.foregroundColor(.secondary)
					.font(.subheadline)
			}

		Image(systemName: "power")
			.resizable()
			.modifier(bounceActionButton(label: label, action: { AbraApp.shared.onShutdown() }))
	}
}

struct RestartButton: View {
	@EnvironmentObject var uiState: UIState

	var body: some View {
		let label =
			VStack(alignment: .leading) {
				Text("Restart")
					.font(.headline)
				Text("Sends a request to all remote devices to reboot")
					.foregroundColor(.secondary)
					.font(.subheadline)
			}

		Image(systemName: "arrow.triangle.2.circlepath")
			.resizable()
			.modifier(bounceActionButton(label: label, action: { AbraApp.shared.onReboot() }))
	}
}

struct CheckForUpdatesButton: View {
	@EnvironmentObject var uiState: UIState

	var body: some View {
		let label =
			VStack(alignment: .leading) {
				Text("Check for Updates")
					.font(.headline)
				Text("Sends a request to all remote devices to check for updates")
					.foregroundColor(.secondary)
					.font(.subheadline)
			}

		Image(systemName: "square.and.arrow.up")
			.resizable()
			.modifier(bounceActionButton(label: label, action: { AbraApp.shared.onCheckForUpdates() }))
	}
}

struct SettingsView: View {
	@EnvironmentObject var uiState: UIState

	var body: some View {
		ScrollView {
			VStack(alignment: .leading) {
				Text("Local Settings").modifier(settingsHeader())
				VStack(alignment: .leading) {
					ResetTrickButton()
					AutoPauseButton(autoPauseEnabled: $uiState.autoPauseEnabled)
					LocalServerButton(localServerEnabled: $uiState.localServerEnabled)
					if uiState.localServerEnabled {
						AdvertiseServerButton(advertiseServer: $uiState.advertiseServer)
					}
				}
				.padding()

				Text("Remote Setings").modifier(settingsHeader(label: "Not available on all remote clients"))
				VStack(alignment: .leading) {
					ShutdownButton()
					RestartButton()
					CheckForUpdatesButton()
				}
				.padding()
			}
		}
		#if os(iOS)
		.navigationBarTitle("Settings", displayMode: .inline)
		#endif
	}
}

struct SettingsView_Previews: PreviewProvider {
	static var previews: some View {
		SettingsView()
			.environmentObject(UIState.shared)
	}
}
