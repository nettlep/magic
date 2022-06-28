//
//  CameraListView.swift
//  Abra
//
//  Created by Paul Nettle on 10/27/21.
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

struct CameraListView: View {
	@EnvironmentObject var uiState: UIState
	@Binding var cameraListVisible: Bool

	var body: some View {
		let cameraDevices = AbraCaptureMediaProvider.shared.cameraDevices
		GeometryReader { geo in
			ZStack {
				List(0..<cameraDevices.count) { index in
					let device = cameraDevices[index]
					HStack(alignment: .top) {
						VStack(alignment: .leading) {
							Text(device.name)
								.font(.title2)
								.foregroundColor(.primary)
							Text("Type: \(device.typeString)")
								.font(.subheadline)
								.foregroundColor(.secondary)
							Text("Location: \(device.positionString)")
								.font(.subheadline)
								.foregroundColor(.secondary)
						}
						Spacer()
					}
					.padding(8)
					// Must set a color with a nearly-invisible opacity here to pick up taps
					.background(Preferences.shared.activeCameraDeviceName == device.name ? Color.accentColor : Color.black.opacity(0.01))
					.onTapGesture {
						withAnimation {
							cameraListVisible = false
							DispatchQueue.global().async {
								AbraCaptureMediaProvider.shared.setCameraDevice(deviceName: device.name)
								AbraCaptureMediaProvider.shared.restartCapture()
							}
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
					cameraListVisible = false
				}
			}
		}
		.transition(.move(edge: .bottom))
	}
}

struct CameraListView_Previews: PreviewProvider {
	static var previews: some View {
		CameraListView(cameraListVisible: .constant(true))
			.environmentObject(UIState.shared)
	}
}
