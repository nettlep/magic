//
//  Preferences.swift
//  Abra
//
//  Created by Paul Nettle on 10/5/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI

internal class Preferences {
	// -----------------------------------------------------------------------------------------------------------------------------
	// Provide a singleton-like interface
	// -----------------------------------------------------------------------------------------------------------------------------

	private static var _shared: Preferences?
	internal static var shared: Preferences
	{
		get
		{
			if _shared == nil
			{
 				_shared = Preferences()
			}

			return _shared!
		}
		set
		{
			assert(_shared != nil)
		}
	}

	var isLocalLoopback: Bool
	{
		return localServerEnabled && !advertiseServer
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	@AppStorage("freeze") var freeze: Bool = false
	@AppStorage("localServerEnabled") var localServerEnabled: Bool = false
	@AppStorage("advertiseServer") var advertiseServer: Bool = true
	@AppStorage("errorCorrectionDisplay") var errorCorrectionDisplay: Bool = false
	@AppStorage("deckFormatName") var deckFormatName: String?
	@AppStorage("activeCameraDeviceName") var activeCameraDeviceName: String?
}
