//
//  SteveFrameView.swift
//  Steve
//
//  Created by Paul Nettle on 11/9/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import Seer
import Minion
import UniformTypeIdentifiers

class SteveFrameView: RenderView
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// View lifecycle
	// -----------------------------------------------------------------------------------------------------------------------------

	override func viewDidMoveToWindow()
	{
		window?.acceptsMouseMovedEvents = true

		registerForDraggedTypes([NSPasteboard.PasteboardType(UTType.fileURL.identifier as String),
								 NSPasteboard.PasteboardType(UTType.item.identifier as String)])
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Viewport updates & notifications
	// -----------------------------------------------------------------------------------------------------------------------------

	func onNewContentSize(_ contentSize: IVector)
	{
		DispatchQueue.main.async
		{
			guard let window = self.window else { return }

			let visibleFrame = NSScreen.screens[0].visibleFrame

			// Our scale factor, adjusted to the backing store
			let factor: CGFloat = CGFloat(1) / window.backingScaleFactor

			// Cheesy method to scale our size such that it fits on the screen, maintaining aspect
			var scaledSize = NSSize(width: CGFloat(contentSize.x) * factor, height: CGFloat(contentSize.y) * factor)
			while scaledSize.width > visibleFrame.width || scaledSize.height > visibleFrame.height
			{
				scaledSize.width *= CGFloat(0.75)
				scaledSize.height *= CGFloat(0.75)
			}

			let windowBorderHeight = window.frame.size.height - self.frame.size.height
			let windowBorderWidth = window.frame.size.width - self.frame.size.width
			let windowSize = NSSize(width: scaledSize.width + windowBorderWidth, height: scaledSize.height + windowBorderHeight)

			// Optional: keep it centered
			let originX = window.frame.origin.x + (window.frame.size.width - windowSize.width) / 2
			let originY = window.frame.origin.y + (window.frame.size.height - windowSize.height) / 2
			let windowFrame = NSRect(x: originX, y: originY, width: windowSize.width, height: windowSize.height)

			window.setFrame(windowFrame, display: true, animate: false)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Mouse input
	// -----------------------------------------------------------------------------------------------------------------------------

	override func mouseDown(with event: NSEvent)
	{
		super.mouseDown(with: event)

		Config.debugDrawMouseEdgeDetection = true
		SteveMediaProvider.instance.playLastFrame()
	}

	override func mouseUp(with event: NSEvent)
	{
		super.mouseUp(with: event)

		Config.debugDrawMouseEdgeDetection = false
	}

	override func mouseDragged(with event: NSEvent)
	{
		guard let window = self.window else { return }
		let factor = window.backingScaleFactor

		super.mouseMoved(with: event)

		Config.debugDrawMouseEdgeDetection = true
		let p = convert(event.locationInWindow, from: nil)
		Config.mousePosition = Vector(x: Real(p.x * factor), y: Real((bounds.height - p.y) * factor))
		SteveMediaProvider.instance.playLastFrame()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Keyboard input
	// -----------------------------------------------------------------------------------------------------------------------------

	override func performKeyEquivalent(with event: NSEvent) -> Bool
	{
		let modCommand = event.modifierFlags.contains(NSEvent.ModifierFlags.command)
		let modControl = event.modifierFlags.contains(NSEvent.ModifierFlags.control)
		let modOption = event.modifierFlags.contains(NSEvent.ModifierFlags.option)
		let modFunction = event.modifierFlags.contains(NSEvent.ModifierFlags.function)
		let modNone = !modCommand && !modControl && !modOption && !modFunction
		guard let key = event.charactersIgnoringModifiers else { return false }
		guard let rawKeyValue = key.unicodeScalars.first?.value else { return false }

		if key == "q" && modNone
		{
			window?.close()
			return true
		}
		else if rawKeyValue == UInt32(NSEvent.SpecialKey.leftArrow.rawValue) && modFunction
		{
			SteveMediaProvider.instance.previous()
			return true
		}
		else if rawKeyValue == UInt32(NSEvent.SpecialKey.rightArrow.rawValue) && modFunction
		{
			SteveMediaProvider.instance.next()
			return true
		}

		return false
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Drag/drop support
	// -----------------------------------------------------------------------------------------------------------------------------

	func shouldAllowDrag(_ draggingInfo: NSDraggingInfo) -> Bool
	{
		return getAllowedUrl(draggingInfo) != nil
	}

	override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation
	{
		return getAllowedUrl(sender) != nil ? .copy : NSDragOperation()
	}

	override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation
	{
		return getAllowedUrl(sender) != nil ? .copy : NSDragOperation()
	}

	override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool
	{
		return getAllowedUrl(sender) != nil
	}

	override func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool
	{
		guard let url = getAllowedUrl(draggingInfo) else { return false }
		let path = PathString(url.path)

		DispatchQueue.main.async
		{
			if !SteveMediaProvider.instance.loadMedia(path: path)
			{
				gLogger.error("Unable to load media file: \(path)")
			}
		}

		return true
	}

	func getAllowedUrl(_ draggingInfo: NSDraggingInfo) -> URL?
	{
		let pasteBoard = draggingInfo.draggingPasteboard
		if let urls = pasteBoard.readObjects(forClasses: [NSURL.self]) as? [URL]
		{
			// Get the path
			if urls.count != 1 { return nil }
			guard let url = urls.first else { return nil }
			let path = url.path.lowercased()

			let allowedFileExtensions = SteveMediaProvider.videoFileExtensions + SteveMediaProvider.imageFileExtensions
			for allowedFileExtension in allowedFileExtensions
			{
				if path.hasSuffix(".\(allowedFileExtension)") { return url }
			}
		}

		return nil
	}
}
