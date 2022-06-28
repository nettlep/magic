//
//  CardBarsAppDelegate.swift
//  CardBars
//
//  Created by Paul Nettle on 11/6/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Cocoa

@NSApplicationMain
class CardBarsAppDelegate: NSObject, NSApplicationDelegate
{
	@IBAction func copy(_ sender: Any)
	{
	}

	func applicationDidFinishLaunching(_ aNotification: Notification)
	{
		// Insert code here to initialize your application
	}

	func applicationWillTerminate(_ aNotification: Notification)
	{
		// Insert code here to tear down your application
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
	{
		return true
	}
}
