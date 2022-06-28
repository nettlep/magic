//
//  ActionButton.swift
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

// swiftlint:disable type_name
struct baseButtonStyle<Label>: ViewModifier where Label: View {
	let kContentSizeSpacingRatio = 0.2
	var label: Label?
	var enabled: Bool = true
	var highlighted: Bool = false

	func body(content: Content) -> some View {
		HStack {
			ZStack {
				if highlighted {
					Circle().fill(Color.highlightedButtonColor)
				}
				Circle().stroke(enabled ? Color.accentColor : Color.gray, lineWidth: AbraApp.kButtonLineWidth)
				content
					.aspectRatio(contentMode: .fit)
					.padding(AbraApp.kButtonSize * kContentSizeSpacingRatio)
			}
			.frame(width: AbraApp.kButtonSize, height: AbraApp.kButtonSize)
			.padding(AbraApp.kButtonLineWidth / 2)
			if let labelContent = label
			{
				labelContent
					.padding(.leading, 5)
					.foregroundColor(enabled ? Color.primary : Color.gray)
			}
		}
		.foregroundColor(enabled ? (highlighted ? Color.black : Color.primary) : Color.gray)
	}
}

// swiftlint:disable type_name
struct baseButton<Label>: ViewModifier where Label: View {
	let kContentSizeSpacingRatio = 0.2
	var label: Label?
	var enabled: Bool = true
	var highlighted: Bool = false
	var action: () -> Void = {}

	func body(content: Content) -> some View {
		content
			.modifier(baseButtonStyle(label: label, enabled: enabled, highlighted: highlighted))
			.onTapGesture {
				if enabled { action() }
			}
	}
}

// swiftlint:disable type_name
struct bellActionButton<Label>: ViewModifier where Label: View {
	@State var angle: CGFloat = 0

	var label: Label?
	var enabled: Bool = true
	var highlighted: Bool = false
	var action: () -> Void = {}

	func body(content: Content) -> some View {
		content
			.rotationEffect(.degrees(angle), anchor: UnitPoint(x: 0.5, y: 0.3))
			.animation(.interpolatingSpring(mass: 1.0, stiffness: 500.0, damping: 5, initialVelocity: 5), value: angle)
			.modifier(baseButton(label: label, enabled: enabled, highlighted: highlighted, action: {
				withAnimation {
					self.angle = 30.3
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
						self.angle = 0
					}
					action()
				}
			}))
	}
}

// swiftlint:disable type_name
struct bounceActionButton<Label>: ViewModifier where Label: View {
	@State private var scale: CGFloat = 1
	var count: Int = 1
	var bounceScale: CGFloat = 1.3

	var label: Label?
	var enabled: Bool = true
	var highlighted: Bool = false
	var action: () -> Void = {}

	func body(content: Content) -> some View {
		content
		.scaleEffect(scale)
		.animation(.interpolatingSpring(mass: 1.0, stiffness: 500.0, damping: 10, initialVelocity: 10), value: scale)
			.modifier(baseButton(label: label, enabled: enabled, highlighted: highlighted, action: {
				scale = bounceScale
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
					scale = 1
					action()
				}
			}))
	}
}

struct ActionButton_Previews: PreviewProvider {
	static var previews: some View {
		Image(systemName: "gearshape").resizable().modifier(bounceActionButton(label: EmptyView()))
		Image(systemName: "gearshape").resizable().modifier(bounceActionButton(label: EmptyView(), highlighted: true))
		Image(systemName: "gearshape").resizable().modifier(bounceActionButton(label: Text("Disabled settings"), enabled: false))
		Image(systemName: "gearshape").resizable().modifier(bounceActionButton(label: Text("Enabled settings"), enabled: true))
		Image(systemName: "bell").resizable().modifier(bellActionButton(label: EmptyView()))
	}
}
