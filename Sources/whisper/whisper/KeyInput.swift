//
//  KeyInput.swift
//  Whisper
//
//  Created by Paul Nettle on 9/5/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import Seer
import Minion

internal final class KeyInput
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Gets key input from the text UI (if present) and processes key input
	///
	/// If a key is unknown, the Returns true if a key was handled, otherwise false
	internal class func process() -> Bool
	{
		// Get the key code
		let keyCode = Int(TextUi.instance.getKey())
		if keyCode < 0 { return false }

		// Transform the key to something more useful
		guard let keyUnicodeScalar = UnicodeScalar(keyCode) else { return false }

		// Something human-readable
		let keyString = String(describing: keyUnicodeScalar)
		//gLogger.trace("Key: \(keyString)")

		switch keyString
		{
		case " ": Whisper.instance.isPaused.toggle()
			case "0": Config.debugDrawScanResults = !Config.debugDrawScanResults
			case "e": Config.debugDrawSequencedEdgeDetection = !Config.debugDrawSequencedEdgeDetection
			case "t": Config.debugDrawTraceMarks = !Config.debugDrawTraceMarks
			case "d": Config.debugDrawDeckExtents = !Config.debugDrawDeckExtents
			case "g": Config.debugDrawFullSearchGrid = !Config.debugDrawFullSearchGrid
			case "G": Config.debugDrawSequentialSearchLineOrder = !Config.debugDrawSequentialSearchLineOrder
			case "n": Config.testbedFilterInputHistogramNormalization = !Config.testbedFilterInputHistogramNormalization
			          gLogger.info("Histogram Normalization \(Config.testbedFilterInputHistogramNormalization ? "Enabled":"Disabled")")
			case "N": if let codeDefinition = Config.searchCodeDefinition
			          {
			              Config.searchCodeDefinition = codeDefinition.nextCodeDefinition()
			          }
		case "p": Whisper.instance.restartPlayback.value = true
			case "R": Config.debugRotateFrame = !Config.debugRotateFrame
			          gLogger.info("180-degree frame rotation \(Config.debugRotateFrame ? "Enabled":"Disabled")")
			case "q": Whisper.instance.shutdown(because: "Quit requested by user")
			case "r": Whisper.instance.mediaConsumer?.resetStats()
			case "s": Config.debugDrawSearchedLines = !Config.debugDrawSearchedLines
			case "V": Config.testbedDrawViewport = !Config.testbedDrawViewport
			          gLogger.info("Viewport drawing \(Config.testbedDrawViewport ? "Enabled":"Disabled")")
			case "w": Whisper.instance.viewportProvider?.writeViewport()
			case "W": _=Whisper.instance.mediaProvider?.archiveFrame(baseName: "debug", async: true)
			case "x": logPerfStats()

			// If we don't understand the key, bail
			default:
				// gLogger.info("Unknown key from user: \(keyString) (\(keyCode))")
				return false
		}

		// At this point, we should have handled the key
		return true
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Logs performance statistics
	private class func logPerfStats()
	{
		gLogger.execute(with: LogLevel.Perf)
		{
			gLogger.perf(String(repeating: "-", count: 132))

			gLogger.perf(Whisper.instance.mediaProvider?.mediaSource ?? "[no media]")
			gLogger.perf("")

			if let viewportProvider = Whisper.instance.viewportProvider
			{
				if !viewportProvider.statsText.isEmpty
				{
					for line in viewportProvider.statsText
					{
						gLogger.perf(line)
					}
					gLogger.perf("")
				}

				if !viewportProvider.perfText.isEmpty
				{
					for line in viewportProvider.perfText
					{
						gLogger.perf(line)
					}
					gLogger.perf("")
				}
			}

			gLogger.perf(PerfTimer.statsString())
		}
	}
}
