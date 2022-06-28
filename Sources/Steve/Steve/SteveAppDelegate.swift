//
//  SteveAppDelegate.swift
//  Steve
//
//  Created by Paul Nettle on 11/7/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Cocoa
import Seer

@NSApplicationMain
class SteveAppDelegate: NSObject, NSApplicationDelegate
{
	func applicationDidFinishLaunching(_ aNotification: Notification)
	{
	}

	func applicationWillTerminate(_ aNotification: Notification)
	{
//		 _ = Config.write()
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
	{
		return true
	}
}
