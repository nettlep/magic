//
//  ConfidenceGaugeView.swift
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

struct ConfidenceGaugeView: View {
	private static let kBottomGapDegrees: Double = 120

	@EnvironmentObject var uiState: UIState

	func gaugeColor(scalarRatio: CGFloat) -> Color {
		let rMin: CGFloat = 0.85
		let rMax: CGFloat = 1.00
		var r: CGFloat
		if scalarRatio < rMin { r = 1 }
		else if scalarRatio >= rMax { r = 0 }
		else { r = 1 - (scalarRatio - rMin) / (rMax - rMin) }

		let gMin: CGFloat = 0.70
		let gMax: CGFloat = 0.85
		var g: CGFloat
		if scalarRatio < gMin { g = 0 }
		else if scalarRatio >= gMax { g = 1 }
		else { g = (scalarRatio - gMin) / (gMax - gMin) }

		return Color(red: r, green: g, blue: 0)
	}

	var body: some View {
		let percent = Double(uiState.confidencePercent)
		let scalarRatio = percent / 100
		let halfGap = ConfidenceGaugeView.kBottomGapDegrees / 2
		let range = (360 - ConfidenceGaugeView.kBottomGapDegrees) / 360
		let minTrim = halfGap / 360
		let kSize = AbraApp.kButtonSize * 1.8
		let lineWidth = kSize * 0.09

		ZStack {
			Color.gray
				.mask(Circle()
						.trim(from: minTrim, to: minTrim + range)
						.stroke(style: StrokeStyle(lineWidth: lineWidth / 3, lineCap: .round))
						.rotationEffect(.degrees(90))
						.padding(lineWidth/2)
				)
			//(percent < 80 ? Color.brightRed : (percent < 90 ? Color.yellow : Color.green))
			gaugeColor(scalarRatio: scalarRatio)
				.mask(Circle()
						.trim(from: minTrim, to: minTrim + range * scalarRatio)
						.stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
						.rotationEffect(.degrees(90))
						.padding(lineWidth/2)
				)
			Image(systemName: uiState.robustDisplay ? "checkmark.shield.fill" : "checkmark.shield")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(height: kSize * 0.4, alignment: .bottom)
				.foregroundColor(.primary)
				.scaleEffect(uiState.robustDisplay ? 1.3 : 1)
				.animation(.interpolatingSpring(stiffness: 500, damping: 15), value: uiState.robustDisplay)
			VStack {
				Spacer()
				Text("\(Int(percent))%")
					.font(.system(size: kSize * 0.2))
					.minimumScaleFactor(0.01)
					.lineLimit(1)
//					.padding(.horizontal)
			}
		}
		.onTapGesture {
			uiState.robustDisplay.toggle()
		}
		.frame(width: kSize, height: kSize)
	}
}

struct ConfidenceGaugeView_Previews: PreviewProvider {
	static var previews: some View {
		ConfidenceGaugeView()
			.environmentObject(UIState.shared)
	}
}
