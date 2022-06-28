//
//  SteveWindow.swift
//  Steve
//
//  Created by Paul Nettle on 3/24/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import Seer
import AppKit
import Minion

final class SteveWindow: NSWindow
{
	override func close()
	{
		gLogger.stop(broadcastMessage: ">>> Session ended")
		super.close()
	}
}
