//
//  BarView.swift
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

@IBDesignable class BarView: NSView
{
	/// The DPI of our saved images used for printing
	let kPrintDPI: Real = 600

	/// The default image DPI
	let kDefaultImageDPI: Real = 72.0

	/// Rubber stamp mode (2mm tall marks)
	var rubberStampMode = false
	let kRubberStampVerticalScale = 4

	/// Real world values
	let kMillimetersPerInch: Real = 25.4

	/// Our deck image
	var deckImage: NSImage?

	/// The backing scale factor of the display (generally, 2.0 for retina displays, otherwise 1.0)
	var backingScaleFactor: Real { return Real(window?.backingScaleFactor ?? 1) }

	/// Vertical scaling factor, to account for things like rubber stamp mode
	var verticalScale: Int { return rubberStampMode ? kRubberStampVerticalScale : 1 }

	// -----------------------------------------------------------------------------------------------------------------------------
	// Drawing
	// -----------------------------------------------------------------------------------------------------------------------------

	override func draw(_ dirtyRect: CGRect)
	{
		super.draw(dirtyRect)

		// Get the code definition
		guard let codeDefinition = Config.searchCodeDefinition else { return }

		window?.title = codeDefinition.format.name + " (\(codeDefinition.widthMM)mm)"

		// Raw width/height
		var deckWidth = CGFloat(codeDefinition.format.printableMaxWidthMM)
		var deckHeight = rubberStampMode ? CGFloat(codeDefinition.format.maxCardCount) : CGFloat(codeDefinition.format.physicalCompressedStackHeightMM)

		// Use the deck aspect to determine how to draw the deck to the window
		let deckAspect = deckWidth / (deckHeight * CGFloat(verticalScale))
		let frameAspect = frame.width / frame.height

		var deckInWindowRect: CGRect
		if deckAspect < frameAspect
		{
			// Limited by view height
			let height = frame.height
			let width = height * deckAspect
			let x = (frame.width - width) / 2
			deckInWindowRect = CGRect(x: x, y: CGFloat(0), width: width, height: height)
		}
		else
		{
			// Limited by view width
			let width = frame.width
			let height = width / deckAspect
			let y = (frame.height - height) / 2
			deckInWindowRect = CGRect(x: CGFloat(0), y: y, width: width, height: height)
		}

		// Dimension of a deck of cards (width-wise)
//		var deckWidth = CGFloat(codeDefinition.format.printableMaxWidthMM)
//		var deckHeight = rubberStampMode ? CGFloat(codeDefinition.format.maxCardCount) : CGFloat(codeDefinition.format.physicalCompressedStackHeightMM)

		deckWidth /= CGFloat(kMillimetersPerInch)
		deckHeight /= CGFloat(kMillimetersPerInch)

		// Scale to print dimensions
		deckWidth *= CGFloat(kPrintDPI)
		deckHeight *= CGFloat(kPrintDPI)

		// Apply backing scale
		deckWidth /= CGFloat(backingScaleFactor)
		deckHeight /= CGFloat(backingScaleFactor)

		// Apply vertical scale
		deckHeight *= CGFloat(verticalScale)

		// Pixel dimensions of the printed code
		let codeWidth = CGFloat(codeDefinition.widthMM / kMillimetersPerInch * kPrintDPI / backingScaleFactor)
		let codeHeight = deckHeight

		// Create an image at full print resolution
		//
		// NOTE: [0, 0] is lower-left
		let deckImageRect = CGRect(x: 0, y: 0, width: Int(deckWidth + 0.5), height: Int(deckHeight + 0.5))
		deckImage = NSImage(size: deckImageRect.size)

		if let deckImage = deckImage
		{
			// The portion of the rect within the image that we will draw our code to
			let codeRect = CGRect(x: (deckWidth - codeWidth) / 2, y: CGFloat(0), width: codeWidth, height: codeHeight)

			// Let's use nearest-neithbor rendering so we get crisp codes
			NSGraphicsContext.current?.cgContext.interpolationQuality = CGInterpolationQuality.none

			// Fill the background (Grey for OK, RED if the deck doesn't fit in the printable area)
			if codeDefinition.widthMM <= codeDefinition.format.printableMaxWidthMM
			{
				NSColor(white: 0.7, alpha: 1).set()
			}
			else
			{
				NSColor(calibratedRed: 1.0, green: 0, blue: 0, alpha: 1).set()
			}
			bounds.fill()

			// Lock the image so we can draw to it
			deckImage.lockFocus()

			// Fill the background for the full deck
			NSColor(white: codeDefinition.format.invertLuma ? 0.0 : 1.0, alpha: 1).set()
			deckImageRect.fill()

			// Draw the code into the deck
			NSColor(white: codeDefinition.format.invertLuma ? 1.0 : 0.0, alpha: 1).set()
			drawDeck(for: codeDefinition, to: codeRect)
			deckImage.unlockFocus()

			// Update the view with our new image
			deckImage.draw(in: deckInWindowRect)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Deck drawing
	// -----------------------------------------------------------------------------------------------------------------------------

	private func drawDeck(for codeDefinition: CodeDefinition, to codeRect: CGRect)
	{
		let format = codeDefinition.format
		let totalCards = format.maxCardCount

		// The height of a single card in the deck
		let cardHeight = codeRect.height / CGFloat(totalCards)

		// Coordinates for drawing a single card
		//
		// Note that we start at the bottom and work upwards
		var cardRect = codeRect
		cardRect.origin.y += codeRect.size.height - cardHeight
		cardRect.size.height = cardHeight

		let indexToCodeMap = format.cardCodesNdo
		for cardIndex in 0..<totalCards
		{
			let cardCode = indexToCodeMap[cardIndex]
			drawCard(codeDefinition: codeDefinition, cardCode: cardCode, cardRect: cardRect)
			cardRect.origin.y -= cardRect.size.height
		}
	}

	private func drawCard(codeDefinition: CodeDefinition, cardCode: Int, cardRect: CGRect)
	{
		let markY = cardRect.origin.y
		let markHeight = cardRect.size.height

		for markDefinition in codeDefinition.markDefinitions
		{
			let markX = cardRect.origin.x + CGFloat(markDefinition.normalizedStart) * cardRect.width
			let markWidth = CGFloat(markDefinition.normalizedWidth) * cardRect.width

			switch markDefinition.type
			{
				case .Landmark:
					drawMark(x: markX, y: markY, w: markWidth, h: markHeight)
				case .Bit(index: _):
					if (cardCode >> markDefinition.type.bitIndex!) & 1 == 1
					{
						drawMark(x: markX, y: markY, w: markWidth, h: markHeight)
					}
				case .Space:
					break
			}
		}
	}

	private func drawMark(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)
	{
		// We round the points individually to avoid error
		let ix0 = Int(x+0.5)
		let iy0 = Int(y+0.5)
		let ix1 = Int(x+w+0.5)
		let iy1 = Int(y+h+0.5)

		CGRect(x: ix0, y: iy0, width: ix1-ix0, height: iy1-iy0).fill()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Mark maps
	// -----------------------------------------------------------------------------------------------------------------------------

	public func printMarkMap(for codeDefinition: CodeDefinition)
	{
		let format = codeDefinition.format
		let indexToCodeMap = format.cardCodesNdo
		let indexToFaceCodeMap = format.faceCodesNdo

		Swift.print("------------------------------------------------------------------------------------------------------")
		Swift.print("Mark map (map of cards that have each bit set) for \(codeDefinition.format.name)")
		Swift.print("------------------------------------------------------------------------------------------------------")
		Swift.print("")

		for bit in 0..<format.cardCodeBitCount
		{
			var bitLine = "  Bit: \(String(format: "%02d", bit)):"
			for cardIndex in 0..<format.maxCardCount
			{
				let cardCode = indexToCodeMap[cardIndex]
				if ((cardCode >> bit) & 1) == 0
				{
					bitLine += " --"
				}
				else
				{
					bitLine += " \(indexToFaceCodeMap[cardIndex].padding(toLength: 2, withPad: " ", startingAt: 0))"
				}
			}

			Swift.print(bitLine)
		}

		Swift.print("")
		Swift.print("------------------------------------------------------------------------------------------------------")
		Swift.print("Card binary map (map of binary codes for each card) for \(codeDefinition.format.name)")
		Swift.print("------------------------------------------------------------------------------------------------------")
		Swift.print("")

		for cardIndex in 0..<format.maxCardCount
		{
			let cardCode = indexToCodeMap[cardIndex]
			let faceCode: String = indexToFaceCodeMap[cardIndex].padding(toLength: 2, withPad: " ", startingAt: 0)
			var cardLine = "  \(faceCode)   "

			for bit in 0..<format.cardCodeBitCount
			{
				if ((cardCode >> bit) & 1) == 0
				{
					cardLine += " --"
				}
				else
				{
					cardLine += " \(bit.toString(2, zero: true))"
				}
			}

			Swift.print(cardLine)
		}

		Swift.print("")
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Saving
	// -----------------------------------------------------------------------------------------------------------------------------

	func unscaledBitmapImageRep(forImage image: NSImage) -> NSBitmapImageRep
	{
		guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(image.size.width), pixelsHigh: Int(image.size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { preconditionFailure() }
		NSGraphicsContext.saveGraphicsState()
		NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
		image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)
		NSGraphicsContext.restoreGraphicsState()
		return rep
	}

	public func save()
	{
		// Filename
		guard let codeDefinition = Config.searchCodeDefinition else { return }
		guard let basePath = PathString.homeDirectory()?.getSubdir("Desktop") ?? PathString.homeDirectory() ?? PathString.currentDirectory() else { return }
		let rubberStampSuffix = rubberStampMode ? "-rubberstamp" : ""
		let filename = "\(codeDefinition.format.name)\(rubberStampSuffix).png"
		let path = URL(fileURLWithPath: "\(basePath.toString())/\(filename)")

		// Set the image's size to its actusal size, taking the backing scale factor into account
		guard let nsImage = deckImage else { return }
		let backingScale = CGFloat(backingScaleFactor)
		nsImage.size = NSSize(width: nsImage.size.width * backingScale, height: nsImage.size.height * backingScale)

		// Get a raw, unscaled image with the proper image DPI set to `kPrintDPI`
		let rep = unscaledBitmapImageRep(forImage: nsImage)
		let scale: CGFloat = CGFloat(kDefaultImageDPI) / CGFloat(kPrintDPI)
		rep.size = NSSize(width: nsImage.size.width * scale, height: nsImage.size.height * scale)

		// Write the image to a file
		guard let pngData = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [.compressionFactor: 1.0]) else { return }
		try? pngData.write(to: path)
	}

	public func toggleRubberStamp()
	{
		rubberStampMode = !rubberStampMode
		needsDisplay = true
	}
}
