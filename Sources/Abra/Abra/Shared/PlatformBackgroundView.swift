//
//  PlatformBackgroundView.swift
//  Abra
//
//  Created by Paul Nettle on 9/30/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI

struct PlatformBackgroundView<Content: View>: View {
	@Environment(\.colorScheme) var colorScheme
	var content: () -> Content

	var body: some View {
		RoundedRectangle(cornerRadius: 8)
			.fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
			.shadow(color: .black.opacity(0.3), radius: 5, x: 8, y: 8)
		content()
	}
}

struct PlatformBackgroundView_Previews: PreviewProvider {
	static var previews: some View {
		PlatformBackgroundView {
			RoundedRectangle(cornerRadius: 8)
				.fill(Color.green)
				.padding()
		}
		PlatformBackgroundView {
			RoundedRectangle(cornerRadius: 8)
				.fill(Color.green)
				.padding()
		}
		.preferredColorScheme(.dark)
	}
}
