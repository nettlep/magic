//
//  Menus.swift
//  Steve
//
//  Created by Paul Nettle on 2/5/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Cocoa
import Foundation
import Seer
import Minion

/// Class that handles menu items and their actions
final class Menus: NSObject
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Menu management
	// -----------------------------------------------------------------------------------------------------------------------------

	struct MenuAction
	{
		let title: String
		let key: String
		let state: (() -> Bool)?
		let responder: (() -> Void)?

		init(title: String, key: String, state: (() -> Bool)? = nil, responder: (() -> Void)? = nil)
		{
			self.title = title
			self.key = key
			self.state = state
			self.responder = responder
		}
	}

	static let kDebugMenuPrePostProcessing =
	[
		MenuAction(title: "View output interpolation",
		           key: "i",
		           state: { Config.testbedViewInterpolation },
		           responder:
					{
						Config.testbedViewInterpolation = !Config.testbedViewInterpolation
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Low pass filter input",
		           key: "",
		           state: { Config.testbedFilterInputLowPass },
		           responder:
					{
						Config.testbedFilterInputLowPass = !Config.testbedFilterInputLowPass
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Histogram normalize input",
		           key: "",
		           state: { Config.testbedFilterInputHistogramNormalization },
		           responder:
					{
						Config.testbedFilterInputHistogramNormalization = !Config.testbedFilterInputHistogramNormalization
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Contrast enhance input",
		           key: "",
		           state: { Config.testbedFilterInputContrastEnhance },
		           responder:
					{
						Config.testbedFilterInputContrastEnhance = !Config.testbedFilterInputContrastEnhance
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Box filter input",
		           key: "",
		           state: { Config.testbedFilterInputBoxFilter },
		           responder:
					{
						Config.testbedFilterInputBoxFilter = !Config.testbedFilterInputBoxFilter
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Hack map input",
		           key: "/",
		           state: { Config.testbedFilterInputHackMap },
		           responder:
					{
						Config.testbedFilterInputHackMap = !Config.testbedFilterInputHackMap
						SteveMediaProvider.instance.playLastFrame()
					}),
	]

	static let kDebugMenuViewStates =
	[
		MenuAction(title: "Enable drawing to the viewport",
		           key: "cmd-v",
		           state: { Config.testbedDrawViewport },
		           responder:
					{
						Config.testbedDrawViewport = !Config.testbedDrawViewport
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Draw scan results",
		           key: "0",
		           state: { Config.debugDrawScanResults },
		           responder:
					{
						Config.debugDrawScanResults = !Config.debugDrawScanResults
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Rotate frame 180-degrees",
		           key: "R",
		           state: { Config.debugRotateFrame },
		           responder:
					{
						Config.debugRotateFrame = !Config.debugRotateFrame
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Draw search lines",
		           key: "s",
		           state: { Config.debugDrawSearchedLines },
		           responder:
					{
						Config.debugDrawSearchedLines = !Config.debugDrawSearchedLines
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Draw full search grid",
		           key: "g",
		           state: { Config.debugDrawFullSearchGrid },
		           responder:
					{
						Config.debugDrawFullSearchGrid = !Config.debugDrawFullSearchGrid
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Draw sequential search line order",
		           key: "cmd-g",
		           state: { Config.debugDrawSequentialSearchLineOrder },
		           responder:
					{
						Config.debugDrawSequentialSearchLineOrder = !Config.debugDrawSequentialSearchLineOrder
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Draw mark lines",
		           key: "m",
		           state: { Config.debugDrawMarkLines },
		           responder:
					{
						Config.debugDrawMarkLines = !Config.debugDrawMarkLines
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Draw all marks",
		           key: "cmd-m",
		           state: { Config.debugDrawAllMarks },
		           responder:
					{
						Config.debugDrawAllMarks = !Config.debugDrawAllMarks
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Draw sharpness graphs",
		           key: "cmd-s",
		           state: { Config.debugDrawSharpnessGraphs },
		           responder:
					{
						Config.debugDrawSharpnessGraphs = !Config.debugDrawSharpnessGraphs
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Draw all edges",
		           key: "e",
		           state: { Config.debugDrawEdges },
		           responder:
					{
						Config.debugDrawEdges = !Config.debugDrawEdges
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Draw edge detection detail",
		           key: "cmd-e",
		           state: { Config.debugDrawSequencedEdgeDetection },
		           responder:
					{
						Config.debugDrawSequencedEdgeDetection = !Config.debugDrawSequencedEdgeDetection
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Previous edge detection detail",
		           key: "shift-e",
		           responder:
					{
						Config.debugEdgeDetectionSequenceId -= 1
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Next edge detection detail",
		           key: "ctl-e",
		           responder:
					{
						Config.debugEdgeDetectionSequenceId += 1
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Draw deck extents",
		           key: "d",
		           state: { Config.debugDrawDeckExtents },
		           responder:
					{
						Config.debugDrawDeckExtents = !Config.debugDrawDeckExtents
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Draw trace marks",
		           key: "t",
		           state: { Config.debugDrawTraceMarks },
		           responder:
					{
						Config.debugDrawTraceMarks = !Config.debugDrawTraceMarks
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Draw deck locations",
		           key: "cmd-d",
		           state: { Config.debugDrawMatchedDeckLocations },
		           responder:
					{
						Config.debugDrawMatchedDeckLocations = !Config.debugDrawMatchedDeckLocations
						Config.debugDrawMatchedDeckLocationDiscards = Config.debugDrawMatchedDeckLocations
						Config.debugDrawDeckMatchResults = Config.debugDrawMatchedDeckLocations
						SteveMediaProvider.instance.playLastFrame()
					}),
	]

	static let kDebugMenuInformation =
	[
		MenuAction(title: "Reset stats",
		           key: "r",
		           responder: {
						SteveViewController.instance.mediaConsumer?.resetStats()
					}),
		MenuAction(title: "Write config file to desktop",
					key: "",
					responder: {
						guard let basePath = PathString.homeDirectory()?.getSubdir("Desktop") else { return }
						_=Config.write(to: "\(basePath.toString())/whisper.conf")
					}),
		MenuAction(title: "Write current debugBuffer",
		           key: "w",
		           responder: {
						SteveViewController.instance.steveMediaViewport.writeViewport()
					}),
		MenuAction(title: "Write current lumaBuffer",
		           key: "shift-w",
		           responder: {
					_ = SteveMediaProvider.instance.archiveFrame(baseName: "debug", async: true)
					}),
		MenuAction(title: "Copy log",
		           key: "cmd-c",
		           responder: { SteveViewController.instance.copyLogToClipboard() }),
		MenuAction(title: "Clear log",
		           key: "cmd-k",
		           responder: { SteveViewController.instance.clearLog() }),
		MenuAction(title: "Dump Hamming Distance Info to log",
				   key: "ctl-h",
				   responder: { Config.searchCodeDefinition?.format.logHammingDistanceInfo() }),
		MenuAction(title: "Dump History Info to log",
				   key: "h",
				   responder:
				   {
						History.instance.logHistory()
					}),
		MenuAction(title: "Bit pattern histogram",
		           key: "2",
		           state: { Config.debugDrawBitPatternHistogram },
		           responder:
					{
						Config.debugDrawBitPatternHistogram = !Config.debugDrawBitPatternHistogram
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Mark length histogram",
		           key: "3",
		           state: { Config.debugDrawMarkHistogram },
		           responder:
					{
						Config.debugDrawMarkHistogram = !Config.debugDrawMarkHistogram
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Dump full deck validation to log",
		           key: "v",
		           responder:
					{
						// If we're not paused, do so now and wait a bit for the last frame to finish
						let wasPlaying = SteveMediaProvider.instance.isPlaying
						if wasPlaying
						{
							SteveMediaProvider.instance.isPlaying = false
							Thread.sleep(forTimeInterval: 0.1)
						}

						// Replay the frame and capture the validation info to the log
						gLogger.execute(with: LogLevel.Result.rawValue | LogLevel.Decode.rawValue | LogLevel.Resolve.rawValue)
						{
							if SteveMediaProvider.instance.replayLastFrame()
							{
								DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
								{
									SteveViewController.instance.copyLogToClipboard()
								}
							}
						}

						// Restore the play state
						if wasPlaying
						{
							SteveMediaProvider.instance.isPlaying = true
						}
					}),
		MenuAction(title: "Dump performance stats to log",
		           key: "x",
		           responder:
					{
						gLogger.execute(with: LogLevel.Perf)
						{
							gLogger.perf(String(repeating: "-", count: 132))
							gLogger.perf(SteveViewController.instance.statusLineText)
							gLogger.perf("")
							gLogger.perf(SteveMediaProvider.instance.mediaSource)
							gLogger.perf("")
							gLogger.perf(SteveViewController.instance.statsText)
							gLogger.perf("")
							gLogger.perf(PerfTimer.statsString())
						}

						DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
						{
							SteveViewController.instance.copyLogToClipboard()
						}
					}),
		MenuAction(title: "Increment GPP",
		           key: "=",
		           responder:
					{
						Config.debugGeneralPurposeParameter += 1
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Decrement GPP",
		           key: "-",
		           responder:
					{
						Config.debugGeneralPurposeParameter -= 1
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Increment GPP (Cmd)",
		           key: "cmd-=",
		           responder:
					{
						Config.debugGeneralPurposeParameterCmd += 1
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Decrement GPP (Cmd)",
		           key: "cmd--",
		           responder:
					{
						Config.debugGeneralPurposeParameterCmd -= 1
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Increment GPP (Ctl)",
		           key: "ctl-=",
		           responder:
					{
						Config.debugGeneralPurposeParameterCtl += 1
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Decrement GPP (Ctl)",
		           key: "ctl--",
		           responder:
					{
						Config.debugGeneralPurposeParameterCtl -= 1
						SteveMediaProvider.instance.playLastFrame()
					}),
	]

	static let kDebugMenuPlayback =
	[
		MenuAction(title: "Play / Pause",
		           key: " ",
		           state: { SteveMediaProvider.instance.isPlaying },
		           responder:
					{
						SteveMediaProvider.instance.isPlaying = !SteveMediaProvider.instance.isPlaying
					}),
		MenuAction(title: "Step forward one frame",
		           key: ".",
		           responder:
					{
						SteveMediaProvider.instance.isPlaying = false
						SteveMediaProvider.instance.step(by: 1)

						// We are in step frame mode for a single frame
//						SteveMediaProvider.instance.isFullSpeedMode = true
//						SteveMediaProvider.instance.setPostFrameCallback { SteveMediaProvider.instance.isFullSpeedMode = false }
					}),
		MenuAction(title: "Step backward one frame",
		           key: ",",
		           responder:
					{
						SteveMediaProvider.instance.isPlaying = false
						SteveMediaProvider.instance.step(by: -1)

						// We are in step frame mode for a single frame
//						SteveMediaProvider.instance.isFullSpeedMode = true
//						SteveMediaProvider.instance.setPostFrameCallback { SteveMediaProvider.instance.isFullSpeedMode = false }
					}),
		MenuAction(title: "Force a frame",
		           key: "f",
		           responder:
					{
						SteveMediaProvider.instance.playLastFrame()
					}),
		MenuAction(title: "Full-speed mode",
		           key: "cmd-f",
		           state: { SteveMediaProvider.instance.isFullSpeedMode },
		           responder:
					{
						// If we're already in step frame mode, then switch to playing normally, otherwise, turn on the state
						SteveMediaProvider.instance.isFullSpeedMode = !SteveMediaProvider.instance.isFullSpeedMode
					}),
		MenuAction(title: "Pause on correct decode",
		           key: "c",
		           state: { Config.debugPauseOnCorrectDecode },
		           responder:
					{
						Config.debugPauseOnCorrectDecode = !Config.debugPauseOnCorrectDecode
						Config.debugPauseOnIncorrectDecode = false
						SteveMediaProvider.instance.isPlaying = true
					}),
		MenuAction(title: "Pause on incorrect decode",
		           key: "ctl-c",
		           state: { Config.debugPauseOnIncorrectDecode },
		           responder:
					{
						Config.debugPauseOnIncorrectDecode = !Config.debugPauseOnIncorrectDecode
						Config.debugPauseOnCorrectDecode = false
						SteveMediaProvider.instance.isPlaying = true
					}),
		MenuAction(title: "Restart playback",
		           key: "p",
		           responder:
					{
						SteveMediaProvider.instance.restart()
					}),
	]

	static let kDebugMenuAppControl =
	[
		MenuAction(title: "Toggle soft breakpoint",
		           key: "b",
		           state: { Config.debugBreakpointEnabled },
		           responder:
		{
			Config.debugBreakpointEnabled = !Config.debugBreakpointEnabled
		}),
		MenuAction(title: "Use Landmark contours",
				   key: "`",
				   state: { Config.searchUseLandmarkContours },
				   responder:
		{
			Config.searchUseLandmarkContours = !Config.searchUseLandmarkContours
			SteveMediaProvider.instance.playLastFrame()
		}),
		MenuAction(title: "Next code definition",
				   key: "N",
				   responder:
		{
			if let codeDefinition = Config.searchCodeDefinition
			{
				Config.searchCodeDefinition = codeDefinition.nextCodeDefinition()
				SteveMediaProvider.instance.playLastFrame()
			}
		}),
	]

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Parsing of the key text into a key with a proper modifier
	class func parseKey(keyString: String, modifier: inout NSEvent.ModifierFlags) -> String
	{
		let key = String(keyString.suffix(1))
		modifier = NSEvent.ModifierFlags(rawValue: 0)
		if keyString.lowercased().contains("shift-") { modifier.update(with: .shift) }
		if keyString.lowercased().contains("cmd-") { modifier.update(with: .command) }
		if keyString.lowercased().contains("ctl-") { modifier.update(with: .control) }
		if keyString.lowercased().contains("opt-") { modifier.update(with: .option) }
		return key
	}

	/// Sets up a submenu labelled `title` with a list of menu actions specified by `menuActions`
	///
	/// Returns a menu item that acts as a submenu containing all of the actions from `menuActions`
	class func setupSubmenu(title: String, menuActions: [MenuAction]) -> NSMenuItem
	{
		let menu = NSMenu(title: title)
		let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
		menuItem.submenu = menu

		for action in menuActions
		{
			var mod: NSEvent.ModifierFlags = NSEvent.ModifierFlags(rawValue: 0)
			let key = parseKey(keyString: action.key, modifier: &mod)
			let m = NSMenuItem(title: action.title,
			                   action: #selector(SteveViewController.handleMenuItem(menuItem:)),
			                   keyEquivalent: key)
			m.keyEquivalentModifierMask = mod
			if action.state != nil
			{
				m.state = action.state!() ? NSControl.StateValue.on : NSControl.StateValue.off
			}
			menu.addItem(m)
		}

		return menuItem
	}
}
