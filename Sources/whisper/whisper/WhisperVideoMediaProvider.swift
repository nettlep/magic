//
//  WhisperVideoMediaProvider.swift
//  Whisper
//
//  Created by Paul Nettle on 9/21/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import Seer
import NativeTasks
import Minion

internal final class WhisperVideoMediaProvider: MediaProvider
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// General properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Singleton interface
	private static var singletonInstance: MediaProvider?
	static var instance: MediaProvider
	{
		get
		{
			if singletonInstance == nil
			{
				singletonInstance = WhisperVideoMediaProvider()
			}

			return singletonInstance!
		}
		set
		{
			assert(singletonInstance != nil)
		}
	}

	/// Media consumer (where our decoded frames are sent for processing)
	private var mediaConsumer: MediaConsumer?

	/// Our primary video decode manager
	private let videoDecoder = VideoDecode()

	//
	// Media file & management
	//

	private var	mediaFiles = [PathString]()
	private var currentMediaFileIndex = 0

	//
	// Image frames
	//

	private var lumaBuffer: LumaBuffer?

	//
	// Signals & semaphores
	//

	var stoppedSemaphore: DispatchSemaphore?

	// -----------------------------------------------------------------------------------------------------------------------------
	//  ____            _                  _     ____             __
	// |  _ \ _ __ ___ | |_ ___   ___ ___ | |   / ___|___  _ __  / _| ___  _ __ _ __ ___   __ _ _ __   ___ ___
	// | |_) | '__/ _ \| __/ _ \ / __/ _ \| |  | |   / _ \| '_ \| |_ / _ \| '__| '_ ` _ \ / _` | '_ \ / __/ _ \
	// |  __/| | | (_) | || (_) | (_| (_) | |  | |__| (_) | | | |  _| (_) | |  | | | | | | (_| | | | | (_|  __/
	// |_|   |_|  \___/ \__\___/ \___\___/|_|   \____\___/|_| |_|_|  \___/|_|  |_| |_| |_|\__,_|_| |_|\___\___|
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Array of supported media file extensions for video formats
	static var videoFileExtensions: [String] { return ["mov", "mp4", "m4v"] }

	/// Array of supported media file extensions for image formats
	static var imageFileExtensions: [String] { return [] } //["png", "jpg", "jpeg", "luma"]

	/// Pre-frame callback
	///
	/// Pre-frame callbacks are blocks that are called prior to processing a video frame through the `MediaConsumer`. This is a
	/// one-time call and must be set for each frame.
	///
	/// Only one callback can be associated at a given time. Therefore, setting two callbacks would result in the first callback
	/// being overridden by the first and only one callback (the second) being called.
	public func setPreFrameCallback(_ callback: @escaping () -> Void)
	{
		assert(preFrameCallback == nil)
		preFrameCallback = callback
	}
	private var preFrameCallback: (() -> Void)?

	/// Post-frame callback
	///
	/// Post-frame callbacks are blocks that are called after processing a video frame through the `MediaConsumer`. This is a
	/// one-time call and must be set for each frame.
	///
	/// Only one callback can be associated at a given time. Therefore, setting two callbacks would result in the first callback
	/// being overridden by the first and only one callback (the second) being called.
	public func setPostFrameCallback(_ callback: @escaping () -> Void)
	{
		assert(postFrameCallback == nil)
		postFrameCallback = callback
	}
	private var postFrameCallback: (() -> Void)?

	/// Returns true if playback is active
	var isPlaying: Bool = false
	{
		didSet
		{
			if isPlaying
			{
				PausableTime.unpause()
			}
			else
			{
				PausableTime.pause()
			}
		}
	}

	/// Returns true if the current frame is being replayed
	var isReplayingFrame: Bool
	{
		return Config.isReplayingFrame
	}

	/// Returns true if in full-speed mode (i.e., processing frames as quickly as possible.)
	///
	/// This is not likely useful for anything but video file source media, in which case frames are decoded/processed from the
	/// video as fast as the CPU will allow, ignoring the framerate stored in the video itself.
	var isFullSpeedMode: Bool
	{
		// Full-speed mode is the only available mode in this decoder
		get
		{
			return true
		}
		set
		{
			// Do nothing
		}
	}

	/// The name of the current video source
	///
	/// This should return an empty string if no video source is active, or the strigg `Camera` for live video.
	var mediaSource: String = ""

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a MediaProvider
	private init()
	{
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// This method should be implemented as:
	///
	///     public func executeWhenNotProcessing<Result>(block: @escaping () -> Result) -> Result
	///     {
	///         return mediaConsumer(block)
	///     }
	///
	/// No default implementation is provided because it is up to the owner to manage the storage of the media consumer, and hence,
	/// it is not available to this protocol.
	public func executeWhenNotProcessing<Result>(_ block: @escaping () -> Result) -> Result
	{
		return mediaConsumer!.executeWhenNotProcessing(block)
	}

	/// Start playback of the first media file
	func start(mediaConsumer: MediaConsumer)
	{
		self.mediaConsumer = mediaConsumer

		let commandLine = CommandLineParser()
		if !commandLine.parseArguments()
		{
			gLogger.error("No media files found (failed to parse command line)")
			return
		}

		// Copy the media files
		mediaFiles = commandLine.mediaFileUrls

		if mediaFiles.count == 0
		{
			gLogger.error("No media files provided on the command line")
			return
		}

		stoppedSemaphore = DispatchSemaphore(value: 0)

		let thread = Thread.init
		{
			var firstFrame = true
			repeat
			{
				// Deal with user input
				_ = KeyInput.process()

				if firstFrame || Whisper.instance.restartPlayback.value
				{
					let videoFileUrl = self.mediaFiles[self.currentMediaFileIndex]
					if !self.videoDecoder.start(path: videoFileUrl)
					{
						gLogger.error("Unable to start media file: '\(videoFileUrl)'")
					}

					Whisper.instance.restartPlayback.value = false
					Whisper.instance.isPaused.value = false
					firstFrame = false
				}

				let shouldScan = Whisper.instance.mediaConsumer?.shouldScan() ?? false
				if Whisper.instance.isPaused.value || !shouldScan
				{
					Thread.sleep(forTimeInterval: 0.1)

					// We're skipping the media consumer, so we have to `present()` ourselves
					TextUi.instance.present()
					TextUi.instance.updateLog()
					continue
				}

				let frameStart = PerfTimer.trackBegin()

				let videoStart = PerfTimer.trackBegin()
				self.lumaBuffer = self.videoDecoder.frame()

				if let lumaBuffer = self.lumaBuffer
				{
					self.preFrameCallback?()
					self.preFrameCallback = nil

					defer
					{
						self.postFrameCallback?()
						self.postFrameCallback = nil
					}

					PerfTimer.trackEnd(name: "Video decode", start: videoStart)

					gLogger.frame("    >> Received video frame of \(lumaBuffer.width)x\(lumaBuffer.height)")

					// Scan the image
					if let codeDefinition = Config.searchCodeDefinition
					{
						Whisper.instance.mediaConsumer?.processFrame(lumaBuffer: lumaBuffer, codeDefinition: codeDefinition)
					}
					else
					{
						gLogger.error("No code definition set, unable to process frame")
					}

					PerfTimer.trackEnd(name: "Full frame", start: frameStart)
				}
				else
				{
					// Time to switch media files, did we reach the end of the media list?
					if self.currentMediaFileIndex >= self.mediaFiles.count - 1
					{
						// If we're not looping, then stop now
						if !Whisper.instance.commandLine.loopVideo
						{
							Whisper.instance.shutdownRequested.value = true
							break
						}
					}

					// Go to the next media file
					self.videoDecoder.stop()
					self.next()
					firstFrame = true
				}
			} while !Whisper.instance.shutdownRequested.value

			self.videoDecoder.stop()

			// Signal that we're fully stopped
			self.stoppedSemaphore?.signal()
		}
		thread.start()
	}

	/// Restart the current media file at the beginning
	func restart()
	{
		Whisper.instance.restartPlayback.value = true
	}

	/// Waits for the media provider to shut down
	func waitUntilStopped()
	{
		stoppedSemaphore?.wait()
	}

	/// Play the last played frame again, processing it as if it is a new frame of input
	func playLastFrame()
	{
		// Not available in this implementation
		assert(false)
	}

	/// Play the last played frame again, re-processing it exactly as it was previously
	///
	/// This is specifically useful for debugging code that with temporal considerations.
	func replayLastFrame() -> Bool
	{
		// Not available in this implementation
		return false
	}

	/// Step the video by `count` frames
	///
	/// If `count` is a positive value, the step will be forward. Conversely, if `count` is a negative value, the step will be in
	/// reverse. Calling with a `count` of `0` will do nothing.
	func step(by count: Int)
	{
		// Not available in this implementation
	}

	/// Load an image or video file at the given `path`.
	///
	/// The media at `path` must be of a supported media type (see `videoFileExtensions` and `imageFileExtensions`.)
	func loadMedia(path: PathString) -> Bool
	{
		// Not available in this implementation
		//
		// Media is pre-configured from the command line when calling `start()`
		return false
	}

	/// Skips to the next media file
	func next()
	{
		if mediaFiles.count > 0
		{
			currentMediaFileIndex = (currentMediaFileIndex + 1) % mediaFiles.count
		}
	}

	/// Skips to the previous media file
	func previous()
	{
		if mediaFiles.count > 0
		{
			currentMediaFileIndex = (currentMediaFileIndex - 1) % mediaFiles.count
		}
	}

	/// Stores the last frame as a `LUMA` image file, containing temporal information for accurate replay of that frame
	func archiveFrame(baseName: String, async: Bool) -> Bool
	{
		if let lumaBuffer = lumaBuffer
		{
			do
			{
				try lumaBuffer.writeLuma(to: baseName, async: async)
				return true
			}
			catch
			{
				gLogger.error(error.localizedDescription)
				return false
			}
		}
		else
		{
			gLogger.warn("No luma buffer available for archival")
			return false
		}
	}

	/// This method must be called whenever media is changed, in order to allow the system to manage a new input resolution
	func onMediaChanged(to path: PathString, withSize size: IVector)
	{
		(self as MediaProvider).onMediaChanged(to: path, withSize: size)
	}
}
