//
//  WhisperMediaViewportProvider.swift
//  Whisper
//
//  Created by Paul Nettle on 5/7/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import Seer
import Minion

/// The Media Viewport Provider is responsible for displaying the the `DebugBuffer` view of the scanning and decoding process. This
/// includes the display of a block of scanning statistics (a `ResultStats` instance).
class WhisperMediaViewportProvider: MediaViewportProvider
{
	/// The size of our debug image
	///
	/// We track this in order to detect size changes so we may resize the window
	private var lastImageSize = IVector()

	// -----------------------------------------------------------------------------------------------------------------------------
	// Local properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The logger device for our textUI
	private var uiLogger = LogDeviceTextUi()

	//
	// Most recent status text info
	//

	private(set) var perfText = [String]()
	private(set) var statsText = [String]()

	// Our currently visible frame buffer
	private var frameBuffer: DebugBuffer?

	// -----------------------------------------------------------------------------------------------------------------------------
	// General implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize our `WhisperMediaViewportProvider` with the `SteveFrameView` that is responsible for the actual GUI display.
	init()
	{
		// We'll initialize with sane defaults, but adjust them as we go
		TextUi.instance.initialize(lumaSize: IVector(x: Config.captureFrameWidth, y: Config.captureFrameHeight))

		// Register our logger
		if !gLogger.registerDevice(device: uiLogger, logMasks: Config.logMasks)
		{
			gLogger.error("Unable to register UI logging device")
		}

		// Update
		TextUi.instance.present()
		TextUi.instance.updateLog()
	}

	func uninit()
	{
		TextUi.instance.uninit()

		print(String(repeating: "-", count: 132))
		if !perfText.isEmpty
		{
			for line in perfText
			{
				print(line)
			}
		}

		print(PerfTimer.statsString())

		// Dump the last bit of the log
		for line in TextUi.instance.logRecentHistory
		{
			print(line.trim())
		}
	}

	func setResizeRequested()
	{
		TextUi.instance.resizeRequested = true
	}

	/// Displays the debug buffer image
	///
	/// Implementors should copy the image buffer and not rely on its memory beyond the extend of this call. In addition, it should
	/// check for changes in the image's dimensions (as the media may have changed since the last call) and react accordingly.
	func updateLocalViewport(debugBuffer: DebugBuffer?)
	{
		if Config.testbedDrawViewport
		{
			if let debugBuffer = debugBuffer
			{
				frameBuffer = DebugBuffer(debugBuffer)

				let thisImageSize = IVector(x: debugBuffer.width, y: debugBuffer.height)
				if lastImageSize != thisImageSize
				{
					lastImageSize = thisImageSize
					TextUi.instance.updateLumaDimensions(lumaSize: thisImageSize)
				}

				TextUi.instance.draw(image: debugBuffer)
			}
		}

		TextUi.instance.present()
		TextUi.instance.updateLog()
	}

	/// Receives a `ResultsStats` display updates to the user
	func updateStats(analysisResult: AnalysisResult, stats: ResultStats)
	{
		// Update our perf stats
		perfText.removeAll()
		perfText.append(PerfTimer.generatePerfStatsText(useAverage: false))
		perfText.append(PerfTimer.generatePerfStatsText(useAverage: true))

		// Display our perf lines
		TextUi.instance.clearPerf()
		for index in 0..<perfText.count
		{
			let text = perfText[index]
			TextUi.instance.perfLine(line: index, text: text)
		}

		// Update the status line
		let isFullSpeedMode = Whisper.instance.mediaProvider?.isFullSpeedMode ?? false
		let isPlaying = Whisper.instance.mediaProvider?.isPlaying ?? false
		let stepFrameStr = "\(isFullSpeedMode ? ">>": isPlaying ? ">︎":"||")"
		let markLineStr = "\(Config.searchUseLandmarkContours ? "~": "|")"
		let autoPause = "AutoPause: \(Config.debugPauseOnIncorrectDecode ? "Inc" : Config.debugPauseOnCorrectDecode ? "Cor":"N/A")"
		let gpp = "GPP(Shf/Opt/Cmd): " +
			"\(Config.debugGeneralPurposeParameter)/" +
			"\(Config.debugGeneralPurposeParameterCmd)/" +
		"\(Config.debugGeneralPurposeParameterCtl)"
		let sharpness = Config.decodeEnableSharpnessDetection ? (ScanManager.decodeSharpnessFactor == 0 ? "" : "SharpFactor: \(String(format: "%.3f", Real(ScanManager.decodeSharpnessFactor)))") : ""
		let format = Config.searchCodeDefinition?.format.name ?? "Unknown"

		// Display our status line
		statsText.removeAll()
		statsText.append("[\(format)] \(stepFrameStr)  \(markLineStr)  \(autoPause)  \(gpp)  \(sharpness)")
		statsText.append("")
		statsText.append("Search:  " + stats.generateSearchStatsText() + String.kNewLine)
		statsText.append("Decode:  " + stats.generateDecodeStatsText() + String.kNewLine)
		statsText.append("         " + stats.generateValidatedDecodeCorrectStatsText() + String.kNewLine)
		statsText.append("Analyze: " + stats.generateAnalyzerStatsText() + String.kNewLine)
		statsText.append("Reports: " + stats.generateValidatedReportsStatsText() + String.kNewLine)
		statsText.append("Overall: " + stats.generateValidatedOverallStatsText() + String.kNewLine)

		// Display our stats lines
		TextUi.instance.clearStat()
		for index in 0..<statsText.count
		{
			let text = statsText[index]
			TextUi.instance.statLine(line: index, text: text)
		}
	}

	/// Provides a mechanism for saving the `DebugBuffer` as a color image (such as PNG or JPG.)
	///
	/// This method is similar to `MediaProvider.archiveFrame()` except that this method stores the debug buffer, which may have
	/// color debug information drawn within that can be useful for, well, debugging.
	func writeViewport()
	{
		do
		{
			try frameBuffer?.writePng(to: PathString("debug.png"), numbered: true)
		}
		catch
		{
			gLogger.error("Failed writing debug.png file: \(error.localizedDescription)")
		}
	}
}
