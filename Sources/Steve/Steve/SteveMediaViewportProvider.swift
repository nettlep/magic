//
//  SteveMediaViewportProvider.swift
//  Steve
//
//  Created by Paul Nettle on 11/9/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Cocoa
import Seer
import CoreWLAN
import Minion

/// The Media Viewport Provider is responsible for displaying the the `DebugBuffer` view of the scanning and decoding process. This
/// includes the display of a block of scanning statistics (a `ResultStats` instance).
class SteveMediaViewportProvider: MediaViewportProvider
{
	/// Our frame view, the thing within our application that actually does the drawing
	private let frameView: SteveFrameView

	/// The size of our debug image
	///
	/// We track this in order to detect size changes so we may resize the window
	private var lastImageSize = IVector()

	/// Initialize our `SteveMediaViewportProvider` with the `SteveFrameView` that is responsible for the actual GUI display.
	init(frameView: SteveFrameView)
	{
		self.frameView = frameView
	}

	/// Displays the debug buffer image
	///
	/// Implementors should copy the image buffer and not rely on its memory beyond the extend of this call. In addition, it should
	/// check for changes in the image's dimensions (as the media may have changed since the last call) and react accordingly.
	func updateLocalViewport(debugBuffer: DebugBuffer?)
	{
		if let debugBuffer = debugBuffer
		{
			let thisImageSize = IVector(x: debugBuffer.width, y: debugBuffer.height)
			if lastImageSize != thisImageSize
			{
				lastImageSize = thisImageSize

				// We only resize if we are not full-screen
				//
				// This full-screen check removed because it must be done on the main thread
				//if !SteveViewController.isFullScreen
				//{
					SteveViewController.instance.frameView.onNewContentSize(thisImageSize)
				//}
			}
			frameView.update(buffer: debugBuffer)
		}
	}

	/// Receives a `ResultsStats` display updates to the user
	func updateStats(analysisResult: AnalysisResult, stats: ResultStats)
	{
		// Display our perf stats
		SteveViewController.instance.perfLineText = PerfTimer.generatePerfStatsText(useAverage: false) + "\n" + PerfTimer.generatePerfStatsText(useAverage: true)

		var statsText =  "Search:  " + stats.generateSearchStatsText() + String.kNewLine
		statsText.append("Decode:  " + stats.generateDecodeStatsText() + String.kNewLine)
		statsText.append("         " + stats.generateValidatedDecodeCorrectStatsText() + String.kNewLine)
		statsText.append("Analyze: " + stats.generateAnalyzerStatsText() + String.kNewLine)
		statsText.append("Reports: " + stats.generateValidatedReportsStatsText() + String.kNewLine)
		statsText.append("Overall: " + stats.generateValidatedOverallStatsText() + String.kNewLine)

		// Display our stats
		SteveViewController.instance.statsText = statsText

		// Update the status line
		let stepFrameStr = "\(SteveMediaProvider.instance.isFullSpeedMode ? "⭆": SteveMediaProvider.instance.isPlaying ? "▶︎":"❚❚")"
		let markLineStr = "\(Config.searchUseLandmarkContours ? "⌇": "┃")"
		let autoPause = "AutoPause: \(Config.debugPauseOnIncorrectDecode ? "Inc" : Config.debugPauseOnCorrectDecode ? "Cor":"N/A")"
		let gpp = "GPP(+/⌃/⌘): " +
			"\(Config.debugGeneralPurposeParameter)/" +
			"\(Config.debugGeneralPurposeParameterCmd)/" +
		"\(Config.debugGeneralPurposeParameterCtl)"
		let sharpness = Config.decodeEnableSharpnessDetection ? (ScanManager.decodeSharpnessFactor == 0 ? "" : "SharpFactor: \(String(format: "%.3f", Real(ScanManager.decodeSharpnessFactor)))") : ""
		let format = Config.searchCodeDefinition?.format.name ?? "Unknown"

		// Display our status line
		SteveViewController.instance.statusLineText = "[\(format)] \(stepFrameStr)  \(markLineStr)  \(autoPause)  \(gpp)  \(sharpness)"
	}

	/// Provides a mechanism for saving the `DebugBuffer` as a color image (such as PNG or JPG.)
	///
	/// This method is similar to `MediaProvider.archiveFrame()` except that this method stores the debug buffer, which may have
	/// color debug information drawn within that can be useful for, well, debugging.
	func writeViewport()
	{
		frameView.writeFrameBuffer(to: PathString("debug.png"), numbered: true)
	}
}
