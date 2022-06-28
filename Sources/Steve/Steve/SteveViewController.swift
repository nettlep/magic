//
//  SteveViewController.swift
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
import AVFoundation
import Seer
import Minion

class SteveViewController: NSViewController, NSTextViewDelegate
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// IB outlets
	// -----------------------------------------------------------------------------------------------------------------------------

	@IBOutlet weak var frameView: SteveFrameView!
	@IBOutlet var logTextView: NSTextView!
	@IBOutlet weak var statusLineTextField: NSTextField!
	@IBOutlet weak var perfLineTextField: NSTextField!
	@IBOutlet weak var statsTextField: NSTextField!

	// -----------------------------------------------------------------------------------------------------------------------------
	// Constants
	// -----------------------------------------------------------------------------------------------------------------------------

	static let kMainQueueKey = "com.paulnettle.steve.mainqueue"
	static let kMainQueueSpecificKey = DispatchSpecificKey<String>()

	private static let kLogTextColor = NSColor(red: 0, green: 0.9, blue: 0, alpha: 1)
	private static let kLogAttributes: [NSAttributedString.Key: Any] =
	[
		NSAttributedString.Key.foregroundColor: kLogTextColor,
		NSAttributedString.Key.font: NSFont(name: "Andale Mono", size: 9)!,
	]

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	//
	// Media-based objects
	//

	private(set) var steveMediaViewport: SteveMediaViewportProvider!
	private(set) var mediaConsumer: MediaConsumer?
	private(set) static var instance: SteveViewController!

	//
	// Log & status output
	//

	private var genericLogger = LogDeviceGeneric()

	// -----------------------------------------------------------------------------------------------------------------------------
	// Status and status lines
	// -----------------------------------------------------------------------------------------------------------------------------

	var statusLineText: String
	{
		get
		{
			return statusLineText_.value
		}
		set
		{
			statusLineText_.mutate { $0 = newValue }
			DispatchQueue.main.async
			{
				self.statusLineTextField.stringValue = self.statusLineText_.value
			}
		}
	}
	private var statusLineText_ = Atomic<String>("")

	var statsText: String
	{
		get
		{
			return statsText_.value
		}
		set
		{
			statsText_.mutate { $0 = newValue }
			DispatchQueue.main.async
			{
				self.statsTextField.stringValue = self.statsText_.value
			}
		}
	}
	private var statsText_ = Atomic<String>("")

	var perfLineText: String
	{
		get
		{
			return perfLineText_.value
		}
		set
		{
			perfLineText_.mutate { $0 = newValue }
			DispatchQueue.main.async
			{
				self.perfLineTextField.stringValue = self.perfLineText_.value
			}
		}
	}
	private var perfLineText_ = Atomic<String>("")

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	required init?(coder: NSCoder)
	{
		super.init(coder: coder)

		SteveViewController.instance = self
		SteveViewController.setMainQueueSpecific()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// View management
	// -----------------------------------------------------------------------------------------------------------------------------

	override func viewDidLoad()
	{
		super.viewDidLoad()

		// Initialize our configuration (yes, this is Steve and not Whisper, but sharing the log is handy)
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
		if !gLogger.registerDevice(device: genericLogger, logMasks: Config.logMasks)
		{
			gLogger.error("Unable to register UI logging device")
		}
		gLogger.start(broadcastMessage: ">>> Session starting >>> VCS revision: Steve[\(SteveVersion)] Seer[\(SeerVersion)]")

		// Create our media consumer
		steveMediaViewport = SteveMediaViewportProvider(frameView: frameView)
		mediaConsumer = MediaConsumer(mediaViewport: steveMediaViewport)
		mediaConsumer?.start(peerFactory: SteveServerPeer.createSteveServerPeer)

		// Load our code definitions first
		CodeDefinition.loadCodeDefinitions()

		// Set the log view with horizontal scrolling
		logTextView.maxSize = CGSize(width: Double.greatestFiniteMagnitude, height: Double.greatestFiniteMagnitude)
		logTextView.isHorizontallyResizable = true
		logTextView.enclosingScrollView?.hasHorizontalScroller = true
		logTextView.textContainer?.widthTracksTextView = false
		logTextView.textContainer?.containerSize = CGSize(width: Double.greatestFiniteMagnitude, height: Double.greatestFiniteMagnitude)

		setupDebugMenu()

		// This little ditty kicks the processor into high gear by keeping it busy
		//
		// Specifically, this prevents Turbo Boost from slowing us down
		DispatchQueue.global(qos: .userInteractive).async
		{
			var foo = 100.0
			while true
			{
				if !SteveMediaProvider.instance.isPlaying
				{
					Thread.sleep(forTimeInterval: 0.25)
				}
				else
				{
					foo = sqrt(foo) * 3.0
					if foo < 1.0
					{
						foo += 100.0
					}
				}
			}
		}
	}

	override func viewDidAppear()
	{
		super.viewDidAppear()

		SteveMediaProvider.instance.start(mediaConsumer: SteveViewController.instance.mediaConsumer!)

		// Configure the log view and point our focus at the `frameView` for key input
		logTextView.delegate = self
		view.window!.makeFirstResponder(frameView)
		view.window!.backgroundColor = NSColor(white: 0.1, alpha: 1.0)
	}

	override func viewWillDisappear()
	{
		super.viewWillDisappear()

		gLogger.stop()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Menu management
	// -----------------------------------------------------------------------------------------------------------------------------

	func setupDebugMenu()
	{
		let debugMenu = NSMenu(title: "Debug")
		let debugMenuItem = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
		debugMenuItem.submenu = debugMenu
		NSApp.mainMenu?.insertItem(debugMenuItem, at: 3)

		debugMenu.addItem(Menus.setupSubmenu(title: "Application", menuActions: Menus.kDebugMenuAppControl))
		debugMenu.addItem(Menus.setupSubmenu(title: "Playback", menuActions: Menus.kDebugMenuPlayback))
		debugMenu.addItem(Menus.setupSubmenu(title: "View states", menuActions: Menus.kDebugMenuViewStates))
		debugMenu.addItem(Menus.setupSubmenu(title: "Information", menuActions: Menus.kDebugMenuInformation))
		debugMenu.addItem(Menus.setupSubmenu(title: "Pre/Post processing", menuActions: Menus.kDebugMenuPrePostProcessing))
	}

	@objc func handleMenuItem(menuItem: NSMenuItem)
	{
		for menu in [Menus.kDebugMenuViewStates,
		             Menus.kDebugMenuInformation,
		             Menus.kDebugMenuAppControl,
		             Menus.kDebugMenuPrePostProcessing,
		             Menus.kDebugMenuPlayback]
		{
			for action in menu
			{
				if action.title == menuItem.title
				{
					action.responder?()
					if action.state != nil
					{
						menuItem.state = action.state!() ? NSControl.StateValue.on : NSControl.StateValue.off
					}
					return
				}
			}
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Log view
	// -----------------------------------------------------------------------------------------------------------------------------

	func updateLog()
	{
		let newLines = genericLogger.getLogLines()
		if !newLines.isEmpty
		{
			DispatchQueue.main.async
			{
				// Smart Scrolling
				let scroll = abs(self.logTextView.visibleRect.maxY - self.logTextView.bounds.maxY) < 50

				// Attributed string
				let attrString = NSAttributedString(string: newLines, attributes: SteveViewController.kLogAttributes)

				// Append string to TextView
				self.logTextView.textStorage?.append(attrString)

				if (scroll) // Scroll to end of the TextView contents
				{
					let r = NSRect(x: 0, y: self.logTextView.frame.height-1, width: self.logTextView.frame.width, height: 1)
					self.logTextView.scrollToVisible(r)
				}
			}
		}
	}

	func clearLog()
	{
		DispatchQueue.main.async
		{
			self.logTextView.string = ""
		}
	}

	func copyLogToClipboard()
	{
		DispatchQueue.main.async
		{
			var logText = String(repeating: "-", count: 132) + String.kNewLine
			logText += "VCS revision:  Steve[\(SteveVersion)]  Seer[\(SeerVersion)]" + String.kNewLine
			logText += self.logTextView.string

			let pasteBoard = NSPasteboard.general
			pasteBoard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)

			pasteBoard.setString(logText, forType: NSPasteboard.PasteboardType.string)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	static var isFullScreen: Bool
	{
		return NSApplication.shared.presentationOptions.contains(NSApplication.PresentationOptions.fullScreen)
	}

	private static func setMainQueueSpecific()
	{
		DispatchQueue.main.setSpecific(key: SteveViewController.kMainQueueSpecificKey, value: SteveViewController.kMainQueueKey)
	}

	static func isOnMainQueue() -> Bool
	{
		return SteveViewController.kMainQueueKey == DispatchQueue.getSpecific(key: SteveViewController.kMainQueueSpecificKey)
	}
}
