//
//  CardBarsViewController.swift
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
import Seer
import Minion

class CardBarsViewController: NSViewController
{
	@IBOutlet var barView: BarView!

	override func viewDidLoad()
	{
		super.viewDidLoad()
		self.view.wantsLayer = true

		// Initialize our configuration
		Config.loadConfiguration(configBaseName: "whisper.conf")

		// Setup the logger
		if !gLogger.registerDevice(device: LogDeviceConsole(), logMasks: Config.logMasks)
		{
			gLogger.error("Unable to register console logging device")
		}
		if !gLogger.registerDevice(device: LogDeviceFile(logFileLocations: Config.logFileLocations, truncate: Config.logResetOnStart), logMasks: Config.logMasks)
		{
			gLogger.error("Unable to register file logging device")
		}
		gLogger.start(broadcastMessage: ">>> Session starting >>> VCS revision: Minion[\(MinionVersion)] Seer[\(SeerVersion)]")

		// Load our code definitions first
		CodeDefinition.loadCodeDefinitions(fastLoad: true, skipIgnored: false)

		setupMenus()
	}

	override func viewWillAppear()
	{
		view.layer?.backgroundColor = NSColor.black.cgColor
	}

	override var representedObject: Any?
	{
		didSet
		{
			// Update the view, if already loaded.
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Menu management
	// -----------------------------------------------------------------------------------------------------------------------------

	func setupMenus()
	{
		let imageMenu = NSMenu(title: "Image")
		let imageMenuItem = NSMenuItem(title: "Image", action: nil, keyEquivalent: "")
		imageMenuItem.submenu = imageMenu
		NSApp.mainMenu?.insertItem(imageMenuItem, at: 3)
		imageMenu.addItem(NSMenuItem(title: "Toggle rubber stamp", action: #selector(toggleRubberStamp(menuItem:)), keyEquivalent: ""))
		imageMenu.addItem(NSMenuItem(title: "Save to desktop", action: #selector(saveToDesktop(menuItem:)), keyEquivalent: ""))
		imageMenu.addItem(NSMenuItem(title: "Dump mark map", action: #selector(dumpMarkMaps(menuItem:)), keyEquivalent: ""))

		let codesMenu = NSMenu(title: "Codes")
		let codesMenuItem = NSMenuItem(title: "Codes", action: nil, keyEquivalent: "")
		codesMenuItem.submenu = codesMenu
		NSApp.mainMenu?.insertItem(codesMenuItem, at: 3)

		for codeDefinition in CodeDefinition.codeDefinitions
		{
			codesMenu.addItem(NSMenuItem(title: codeDefinition.format.name, action: #selector(setCodeDefinition(menuItem:)), keyEquivalent: ""))
		}
	}

	@objc func saveToDesktop(menuItem: NSMenuItem)
	{
		barView.save()
	}

	@objc func toggleRubberStamp(menuItem: NSMenuItem)
	{
		barView.toggleRubberStamp()
	}

	@objc func dumpMarkMaps(menuItem: NSMenuItem)
	{
		guard let codeDefinition = Config.searchCodeDefinition else { return }
		barView.printMarkMap(for: codeDefinition)
	}

	@objc func setCodeDefinition(menuItem: NSMenuItem)
	{
		guard let codeDefinition = CodeDefinition.findCodeDefinition(byName: menuItem.title) else
		{
			Swift.print("Failed to find code definition: \(menuItem.title)")
			return
		}

		Config.searchCodeDefinition = codeDefinition
		barView.needsDisplay = true
	}
}
