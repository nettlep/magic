//
//  BouncingGapGesture.swift
//  Abra
//
//  Created by Paul Nettle on 10/3/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI

// swiftlint:disable type_name

/// A modified version of `.onTapGesture` that applies a quick scaling "bouncing" spring animation, applied to the scale of the view.
///
/// Use it like so:
///
/// 	@State var scale: CGFloat = 1
/// 	SomeView()
///			.modifier(bouncingTapGesture(scale: $scale, bounceScale: 1.3) {
///				// your code here to manage the tap gesture
///			})
///
///	Note that the provided block is executed at the peak of the bounce animation. If, for example the block alters an icon image,
///	that transition will happen at the peak of the initial bounce before returning to the original size.
struct bouncingTapGesture: ViewModifier {
	@State private var scale: CGFloat = 1
	var count: Int = 1
	var bounceScale: CGFloat
	var action: () -> Void = {}

	func body(content: Content) -> some View {
		content
			.scaleEffect(scale)
			.animation(.interpolatingSpring(mass: 1.0, stiffness: 500.0, damping: 10, initialVelocity: 10), value: scale)
			.onTapGesture(count: count) {
				scale = bounceScale
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
					scale = 1
					action()
				}
			}
	}
}
