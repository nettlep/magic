//
//  UIState.swift
//  Abra
//
//  Created by Paul Nettle on 10/5/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import SwiftUI
#if os(iOS)
import SeerIOS
import MinionIOS
#else
import Seer
import Minion
#endif

internal class UIState: ObservableObject
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Provide a singleton-like interface
	// -----------------------------------------------------------------------------------------------------------------------------

	internal static let shared = UIState()

	// Prevent external instantiation
	private init() {}

	// -----------------------------------------------------------------------------------------------------------------------------
	// General state properties
	// -----------------------------------------------------------------------------------------------------------------------------

	@Published var paused: Bool = false
	@Published var viewportType: ViewportMessage.ViewportType = .LumaResampledToViewportSize
	@Published var autoPauseEnabled: Bool = false
	@Published var ndo: Bool = false
	@Published var angularLayoutDeck: Bool = true
	@Published var robustDisplay: Bool = false
	@Published var localServerEnabled: Bool = false
	@Published var advertiseServer: Bool = true
	@Published var feedback: String = ""
	@Published var perfFps: String = ""
	@Published var perfFullFrameMs: String = ""
	@Published var perfScanMs: String = ""
	@Published var cardCount: Int = 0
	@Published var confidencePercent: Int = 0
	@Published var serverVersions: [String: String]?
	@Published var serverAddress: Ipv4SocketAddress?
	@Published var cards = [Card]()
	@Published var viewportImage: Image?
	@Published var flaggedFacecodes = [String]()
	@Published var deckFormatName: String?

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	internal var isConnected: Bool
	{
		return serverAddress != nil
	}

	internal func resetTrickState()
	{
		ndo = false
		feedback = ""
		cardCount = 0
		confidencePercent = 0
		cards.removeAll()
		flaggedFacecodes = [String]()
	}

	internal func isFacecodeFlagged(_ faceCode: String) -> Bool
	{
		return flaggedFacecodes.contains { element in
			return element.first == faceCode.first
		}
	}

	internal func toggleFlaggedFacecode(_ faceCode: String)
	{
		if isFacecodeFlagged(faceCode) {
			flaggedFacecodes.removeAll { element in
				return element.first == faceCode.first
			}
		} else {
			flaggedFacecodes.append(faceCode)
		}
	}
}
