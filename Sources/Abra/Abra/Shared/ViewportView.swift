//
//  ViewportView.swift
//  Abra
//
//  Created by Paul Nettle on 9/18/21.
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

struct PausedButton: View {
	@EnvironmentObject var uiState: UIState

	var body: some View {
		GeometryReader { geo in
			HStack {
					Image(systemName: "play.circle")
						.resizable()
						.foregroundColor(.white)
						.padding(geo.size.height * 0.1)
						.aspectRatio(1, contentMode: .fit)

			}
			.background(Color.mediumGray)
			.clipShape(Circle())
			.scaleEffect(uiState.paused ? 1 : 0.75)
			.opacity(uiState.paused ? 1 : 0)
			.animation(.easeInOut(duration: 0.1), value: uiState.paused)
		}
		.aspectRatio(1, contentMode: .fit)
	}
}

struct CameraSelectButton: View {
	@Binding var cameraListVisible: Bool

	var body: some View {
		Image(systemName: "camera")
			.resizable()
			.foregroundColor(.white)
			.modifier(bounceActionButton(label: EmptyView()) {
				withAnimation {
					cameraListVisible.toggle()
				}
			})
			.background(Color.mediumGray)
			.clipShape(Circle())
	}
}

struct ZoomButton: View {
	@Binding var viewportType: ViewportMessage.ViewportType

	var body: some View {
		Image(systemName: viewportType == .LumaCenterViewportRect ? "minus" : "plus")
			.resizable()
			.foregroundColor(.white)
			.modifier(bounceActionButton(label: EmptyView()) {
				if viewportType == .LumaCenterViewportRect {
					ServerConfig.shared.setViewportType(viewportType: .LumaResampledToViewportSize)
				} else {
					ServerConfig.shared.setViewportType(viewportType: .LumaCenterViewportRect)
				}
			})
			.background(Color.mediumGray)
			.clipShape(Circle())
	}
}

// Resizes a view to account for overhang of another view that uses .offset() to achieve the overhang
struct BottomHangResizeView<Content: View>: View {
	// Aspect ratio of the parent
	@State var parentAspect: CGFloat

	// The ratio of the height of the overhanging content to the height of the parent
	@State var contentSizeRatio: CGFloat

	// How much of the view to overhang? For half overhang, use 0.5
	@State var overhangRatio: CGFloat = 0.5

	var content: () -> Content

	var body: some View {
		VStack(spacing: 0) {
			content()
				.aspectRatio(parentAspect, contentMode: .fit)
			Spacer()
		}
		.aspectRatio(parentAspect * (1 - contentSizeRatio * overhangRatio), contentMode: .fit)
	}
}

struct ViewportView: View {
	@Environment(\.colorScheme) var colorScheme
	@EnvironmentObject var uiState: UIState
	@Binding var cameraListVisible: Bool

	let kViewportAspect: CGFloat = 16.0 / 9.0
	let kPlayButtonDiameterRatio: CGFloat = 0.35

	var body: some View {
		ZStack {
			if uiState.isConnected {
				if let img = uiState.viewportImage {
					img
						.resizable()
						.aspectRatio(kViewportAspect, contentMode: .fit)
						.cornerRadius(8)
						.padding(.bottom)
					RoundedRectangle(cornerRadius: 8)
						.stroke(Color.primary, lineWidth: 1)
						.aspectRatio(kViewportAspect, contentMode: .fit)
						.overlay(
							VStack {
								Spacer()
								HStack {
									Spacer()
									// We don't currently support zooming on local servers since they use the full native viewports
									if uiState.localServerEnabled {
										CameraSelectButton(cameraListVisible: $cameraListVisible)
											.frame(height: AbraApp.kButtonSize)
											.shadow(color: .black.opacity(0.3), radius: 5, x: 8, y: 8)
											.padding()
									} else {
										ZoomButton(viewportType: $uiState.viewportType)
											.frame(height: AbraApp.kButtonSize)
											.shadow(color: .black.opacity(0.3), radius: 5, x: 8, y: 8)
											.padding()
									}
								}
							})
						.padding(.bottom)
				} else {
					RoundedRectangle(cornerRadius: 8)
						.fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
						.padding(.bottom)
				}

				VStack {
					Spacer()
					HStack {
						Text("FPS: \(uiState.perfFps) (\(uiState.perfFullFrameMs)ms) : \(uiState.perfScanMs)ms")
							.font(.system(size: 10, design: .monospaced))
							.lineLimit(1)
							.minimumScaleFactor(0.01)
							.padding(.leading)
						Spacer()
					}
				}

				PausedButton()
					.frame(height: AbraApp.kButtonSize * 1.5)
					.shadow(color: .black.opacity(0.3), radius: 5, x: 8, y: 8)
			} else {
				RoundedRectangle(cornerRadius: 8)
					.fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
					.padding(.bottom)

				HStack {
					LocalServerButton(withLabel: false, localServerEnabled: $uiState.localServerEnabled)
					Text("Not connected. Start a server on the local network or enable a local server on this device.")
						.minimumScaleFactor(0.01)
						.frame(maxWidth: 400)
				}
				.padding()
			}
		}
		.onTapGesture {
			if uiState.isConnected {
				uiState.paused.toggle()
			}
		}
		.if(uiState.isConnected) {
			$0.aspectRatio(kViewportAspect, contentMode: .fit)
		}
	}
}

struct ViewportView_Previews: PreviewProvider {
	static var previews: some View {
		ViewportView(cameraListVisible: .constant(false))
			.environmentObject({ () -> UIState in
				let v = UIState.shared
				v.serverAddress = Ipv4SocketAddress(address: 0, port: 0)
				v.localServerEnabled = false
				v.viewportImage = Image(systemName: "viewfinder")
				return v
			}())
	}
}
