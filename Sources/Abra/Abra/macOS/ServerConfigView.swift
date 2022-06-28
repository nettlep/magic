//
//  ServerConfigView.swift
//  magic
//
//  Created by Paul Nettle on 10/16/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI
import Combine
import Seer
import Minion

// swiftlint:disable private_over_fileprivate

fileprivate struct DescriptionView: View {
	@Binding var configValue: ServerConfig.Value

	var body: some View {
		HStack {
			Text(configValue.description)
				.font(.subheadline)
				.foregroundColor(.secondary)
				.fixedSize(horizontal: false, vertical: true)
				.lineLimit(1)
			Spacer()
		}
	}
}

fileprivate struct TextInputView: View {
	@Binding var configValue: ServerConfig.Value
	@State private var isEditing = false
	var filter: String?
	var commitAction: (String) -> Void

	var body: some View {
		VStack {
			HStack {
				TextField(configValue.name, text: $configValue.uiStringValue) { isEditing in
					self.isEditing = isEditing
				} onCommit: {
					commitAction(configValue.uiStringValue)
				}
				.frame(maxWidth: 100)
				.disableAutocorrection(true)
				.border(Color.secondary)
				.onReceive(Just(configValue.uiStringValue)) { newValue in
					if let filter = filter {
						let filtered = newValue.filter { filter.contains($0) }
						if filtered != newValue {
							self.configValue.uiStringValue = filtered
						}
					} else {
						configValue.uiStringValue = newValue
					}
				}

				Text(configValue.name)
					.foregroundColor(isEditing ? .accentColor : .primary)
					.lineLimit(1)

				Spacer()
			}

			DescriptionView(configValue: $configValue)
		}
		.help(Text("[\(String(describing: configValue.type))] \(configValue.description)"))
	}
}

fileprivate struct BooleanValueView: View {
	@Binding var configValue: ServerConfig.Value

	var body: some View {
		VStack(alignment: .leading) {
			Toggle(isOn: $configValue.booleanValue) {
				Text(configValue.name)
					.lineLimit(1)
			}

			DescriptionView(configValue: $configValue)
		}
		.help(Text("\(configValue.uiStringValue) (\(String(describing: configValue.type))) \(configValue.description)"))
	}
}

fileprivate struct ConfigValueView: View {
	@Binding var configValue: ServerConfig.Value

	var body: some View {
		switch configValue.type {
		case .String:
			TextInputView(configValue: $configValue) { stringValue in
				configValue.set(value: stringValue)
			}
		case .StringMap:
			// Not currently supported/needed
			EmptyView()
		case .PathArray:
			// Not currently supported/needed
			EmptyView()
		case .CodeDefinition:
			// This is handled by the Format Button on the main ScannerView
			EmptyView()
		case .Path:
			TextInputView(configValue: $configValue) { stringValue in
				configValue.set(value: PathString(stringValue))
			}
		case .Boolean:
			BooleanValueView(configValue: $configValue)
		case .Integer:
			TextInputView(configValue: $configValue, filter: "0123456789-+") { stringValue in
				configValue.set(value: Int(stringValue) ?? 0)
			}
		case .FixedPoint:
			TextInputView(configValue: $configValue, filter: "0123456789-+.") { stringValue in
				configValue.set(value: (Float(stringValue) ?? 0).toFixed())
			}
		case .Real:
			TextInputView(configValue: $configValue, filter: "0123456789-+.") { stringValue in
				configValue.set(value: Real(stringValue) ?? 0)
			}
		case .RollValue:
			TextInputView(configValue: $configValue, filter: "0123456789-+.") { stringValue in
				configValue.set(value: RollValue(stringValue) ?? 0)
			}
		case .Time:
			TextInputView(configValue: $configValue, filter: "0123456789-+.") { stringValue in
				configValue.set(value: Time(stringValue) ?? 0)
			}
		}
	}
}

struct ServerConfigView: View {
	@EnvironmentObject var uiState: UIState
	@EnvironmentObject var serverConfig: ServerConfig

	func categories(sortedValues: [ServerConfig.Value]) -> [String] {
		var categories: Set<String> = []
		for value in sortedValues {
			categories.insert(value.category)
		}
		return Array(categories.sorted())
	}

	var body: some View {
		VStack {
			if serverConfig.values.count > 0 {
				VStack {
					HStack {
						Spacer()
						Text("Connected server:")
						Text("[\(uiState.localServerEnabled ? "Local server" : uiState.serverAddress?.toString() ?? "unknown")]")
						Spacer()
					}
					.padding()
					.background(Color.accentColor)
				}
				ScrollView {
					ForEach(categories(sortedValues: serverConfig.values), id: \.self) { category in
						VStack(alignment: .leading) {
							Text(category.uppercased())
								.font(.headline)
								.foregroundColor(.accentColor)
							ForEach(0..<serverConfig.values.count, id: \.self) { index in
								if category == serverConfig.values[index].category {
									ConfigValueView(configValue: $serverConfig.values[index])
										.padding(5)
								}
							}
						}
					}
				}
				.padding()
			} else {
				Spacer()
				Text("Nothing to see here.")
				Text("Please connect to a server.")
				Spacer()
			}
		}
	}
}

struct DeviceSettingsView_Previews: PreviewProvider {
	static func populateTestData() -> Bool {
		ServerConfig.shared.populate(SeerServerPeer.buildConfigValueListMessage().configValues)
		return true
	}

	static var previews: some View {
		if populateTestData() {
			ServerConfigView()
				.environmentObject(UIState.shared)
				.environmentObject(ServerConfig.shared)
				.preferredColorScheme(.dark)
		}
		if populateTestData() {
			ServerConfigView()
				.environmentObject(UIState.shared)
				.environmentObject(ServerConfig.shared)
				.background(Color.white)
				.preferredColorScheme(.light)
		}
	}
}
