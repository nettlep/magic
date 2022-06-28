//
//  CommandLineParser.swift
//  Whisper
//
//  Created by Paul Nettle on 4/2/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import Seer
import Minion

internal final class CommandLineParser
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	internal let k6BitInterleaved = "inter6"
	internal let k12BitMDS54 = "mds12-54"
	internal let k12BitMDS54r = "mds12-54r"
	internal let k18BitMDS56 = "mds18-56"
	internal let k12BitMDS104 = "mds12-104"

	// -----------------------------------------------------------------------------------------------------------------------------
	// Options
	// -----------------------------------------------------------------------------------------------------------------------------

	/// If true, the config file will be re-written on exit with current settings
	internal var updateConfigOnExit = false

	/// If true, the Text-based UI is used
	internal var useTextUi = true

	/// If true, the full set of videos will be repeated
	internal var loopVideo = false

	/// The search code definition
	internal var searchCodeDefinitionName: String?

	/// Array of video file URLs to decode
	internal var mediaFileUrls = [PathString]()

	// -----------------------------------------------------------------------------------------------------------------------------

	/// Prints a message to the user with help for our command line interface
	private func printUsage()
	{
		let programName = PathString(CommandLine.arguments[0]).lastComponent() ?? "Whisper"

		print("Usage: \(programName) [options] [video-file] [luma-debug-file]")
		print("")
		print("  OPTIONS:")
		print("")
		print("      -6        (--6-bit)              Override Code Definition in \(Whisper.instance.kConfigFileBaseName) with '\(k6BitInterleaved)'")
		print("      -12       (--12-bit-54)          Override Code Definition in \(Whisper.instance.kConfigFileBaseName) with '\(k12BitMDS54)'")
		print("      -12r      (--12-bit-54r)         Override Code Definition in \(Whisper.instance.kConfigFileBaseName) with '\(k12BitMDS54r)'")
		print("      -104      (--12-bit-104)         Override Code Definition in \(Whisper.instance.kConfigFileBaseName) with '\(k12BitMDS104)'")
		print("      -18       (--18-bit-56)          Override Code Definition in \(Whisper.instance.kConfigFileBaseName) with '\(k18BitMDS56)'")
		print("      -720      (--720p)               Override capture.Frame* in \(Whisper.instance.kConfigFileBaseName) with 1280x720")
		print("      -1080     (--1080p)              Override capture.Frame* in \(Whisper.instance.kConfigFileBaseName) with 1920x1080")
		print("      -h        (--help)               Print this help")
		print("      -l        (--loop-video)         Put video playback on endless loop")
		print("                --update-config        Update (overwrite) the configuration file upon exit")
		print("      -x        (--no-text-ui)         Disable text UI (also disables validation to save on performance)")
		print("")
		print("  NOTES:")
		print("")
		print("  * The currently configured code definition is '\(Config.searchCodeDefinition?.format.name ?? "- none -")'")
		print("")
		print("  * The currently configured capture resolution is \(Config.captureFrameWidth)x\(Config.captureFrameHeight)")
		print("")
		print("  * \(programName) will perform the first configured operation:")
		print("      - Debug luma image")
		print("      - Video decode")
		print("      - Camera capture")
		print("")
	}

	// -----------------------------------------------------------------------------------------------------------------------------

	/// Processes the command line arguments, setting flags and configuration values as necessary
	///
	/// Returns true if parsing was successful, otherwise false. Callers should call `printUsage` on a false return unless they have
	/// a valid reason for not doing so.
	internal func parseArguments() -> Bool
	{
		for i in 1..<CommandLine.arguments.count
		{
			let arg = CommandLine.arguments[i]

			if arg.hasPrefix("-")
			{
				switch arg
				{
					case "-6", "--6-bit":
						searchCodeDefinitionName = k6BitInterleaved

					case "-12", "--12-bit-54":
						searchCodeDefinitionName = k12BitMDS54

					case "-12b", "--12-bit-54r":
						searchCodeDefinitionName = k12BitMDS54r

					case "-104", "--12-bit-104":
						searchCodeDefinitionName = k12BitMDS104

					case "-18", "--18-bit-56":
						searchCodeDefinitionName = k18BitMDS56

					case "-720", "--720p":
						Config.captureFrameWidth = 1280
						Config.captureFrameHeight = 720

					case "-1080", "--1080p":
						Config.captureFrameWidth = 1920
						Config.captureFrameHeight = 1080

					case "-h", "--help":
						printUsage()
						return false

					case "-l", "--loop-video":
						loopVideo = true

					case "--update-config":
						updateConfigOnExit = true

					case "-x", "--no-text-ui":
						useTextUi = false
						Config.debugValidateResults = false

					default:
						print("Unknown option: '\(arg)'")
						printUsage()
						return false
				}
			}
			else
			{
				let path = PathString(arg)
				mediaFileUrls.append(path)
			}
		}

		return true
	}
}
