//
//  WhisperCaptureMediaProvider.swift
//  Whisper
//
//  Created by Paul Nettle on 6/10/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#if USE_MMAL
import Foundation
import Seer
import NativeTasks
import Minion

internal final class WhisperCaptureMediaProvider: MediaProvider
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// General properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Singleton interface
	private static var singletonInstance: WhisperCaptureMediaProvider?
	static var instance: WhisperCaptureMediaProvider
	{
		get
		{
			if singletonInstance == nil
			{
				singletonInstance = WhisperCaptureMediaProvider()
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

	/// Used by the capture system to denote that a frame is currently being processed
	private var processingFrame = false

	//
	// Image frames
	//

	private var lumaBuffer: LumaBuffer?

	//
	// Signals & semaphores
	//

	var stoppedSemaphore: DispatchSemaphore?

	// -----------------------------------------------------------------------------------------------------------------------------
	// Private implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Receive and process images as they are captured
	private func internalCaptureReceiverHandler(_ buffer: UnsafeMutablePointer<LumaSample>?, _ width: UInt32, _ height: UInt32)
	{
		let _track_ = PerfTimer.ScopedTrack(name: "Full frame"); _track_.use()

		if Whisper.instance.shutdownRequested.value
		{
			return
		}

		// Deal with user input before we process the frame
		_ = KeyInput.process()

		let shouldScan = Whisper.instance.mediaConsumer?.shouldScan() ?? false
		if Whisper.instance.isPaused.value || !shouldScan
		{
			// We're skipping the media consumer, so we have to `present()` ourselves
			TextUi.instance.present()
			TextUi.instance.updateLog()
			return
		}

		// Make sure we have a valid code definition
		guard let codeDefinition = Config.searchCodeDefinition else
		{
			gLogger.error("No code definition set, unable to process frame")
			TextUi.instance.present()
			TextUi.instance.updateLog()
			return
		}

		let frameStart = PerfTimer.trackBegin()

		let w = Int(width)
		let h = Int(height)

		if let rawLumaBuffer = buffer
		{
			gLogger.frame(String(format: "    >> Received capture frame of %dx%d", w, h))

			// Create an ImageBuffer in which we own the buffer memory (i.e., faster and no copy required)
			lumaBuffer = LumaBuffer(width: w, height: h, buffer: rawLumaBuffer)

			preFrameCallback?()
			preFrameCallback = nil

			defer
			{
				postFrameCallback?()
				postFrameCallback = nil
			}

			// Scan the image
			processingFrame = true
			Whisper.instance.mediaConsumer?.processFrame(lumaBuffer: lumaBuffer!, codeDefinition: codeDefinition)
			processingFrame = false
		}
		else
		{
			gLogger.error(String(format: "    >> Received nil buffer frame of %dx%d", w, h))
		}
	}

	/// Intermediary handler for passing the actual work to the instance of our media provider
	private class func captureReceiverHandler(_ buffer: UnsafeMutablePointer<LumaSample>?, _ width: UInt32, _ height: UInt32)
	{
		WhisperCaptureMediaProvider.instance.internalCaptureReceiverHandler(buffer, width, height)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	//  ____            _                  _     ____             __
	// |  _ \ _ __ ___ | |_ ___   ___ ___ | |   / ___|___  _ __  / _| ___  _ __ _ __ ___   __ _ _ __   ___ ___
	// | |_) | '__/ _ \| __/ _ \ / __/ _ \| |  | |   / _ \| '_ \| |_ / _ \| '__| '_ ` _ \ / _` | '_ \ / __/ _ \
	// |  __/| | | (_) | || (_) | (_| (_) | |  | |__| (_) | | | |  _| (_) | |  | | | | | | (_| | | | | (_|  __/
	// |_|   |_|  \___/ \__\___/ \___\___/|_|   \____\___/|_| |_|_|  \___/|_|  |_| |_| |_|\__,_|_| |_|\___\___|
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Array of supported media file extensions for video formats
	static var videoFileExtensions: [String] { return [] }

	/// Array of supported media file extensions for image formats
	static var imageFileExtensions: [String] { return [] }

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
		// Full-speed mode makes no sense for a camera
		get
		{
			return false
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

	/// Initialize a MediaProvider with a consumer capable of consuming the media as it arrives
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

	/// Start camera capture
	func start(mediaConsumer: MediaConsumer)
	{
		self.mediaConsumer = mediaConsumer

		let width = UInt32(Config.captureFrameWidth)
		let height = UInt32(Config.captureFrameHeight)
		let rate = UInt32(Config.captureFrameRateHz)
		if let errMsg = nativeVideoCaptureStart(width, height, rate, { (buffer, width, height) in WhisperCaptureMediaProvider.captureReceiverHandler(buffer, width, height)})
		{
			gLogger.error("nativeVideoCaptureStart() returned error: \(errMsg)")
			return
		}

		stoppedSemaphore = DispatchSemaphore(value: 0)

		let thread = Thread.init
		{
			while !Whisper.instance.shutdownRequested.value
			{
				// Rest for a millisecond
				Thread.sleep(forTimeInterval: 0.001)
			}

			// Stop capturing
			nativeVideoCaptureStop()

			// Wait for processing of the last frame to finish before quitting
			while self.processingFrame
			{
				// Rest for one millisecond
				Thread.sleep(forTimeInterval: 0.001)
			}

			// Signal that we're fully stopped
			self.stoppedSemaphore?.signal()
		}
		thread.start()
	}

	/// Restart the current media file at the beginning
	func restart()
	{
		// Not available in this implementation
		//
		// Video capture has no media
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
		//
		// Video capture has no media
	}

	/// Play the last played frame again, re-processing it exactly as it was previously
	///
	/// This is specifically useful for debugging code that with temporal considerations.
	func replayLastFrame() -> Bool
	{
		// Not available in this implementation
		//
		// Video capture has no media
		return false
	}

	/// Step the video by `count` frames
	///
	/// If `count` is a positive value, the step will be forward. Conversely, if `count` is a negative value, the step will be in
	/// reverse. Calling with a `count` of `0` will do nothing.
	func step(by count: Int)
	{
		// Not available in this implementation
		//
		// Video capture has no media
	}

	/// Load an image or video file at the given `path`.
	///
	/// The media at `path` must be of a supported media type (see `videoFileExtensions` and `imageFileExtensions`.)
	func loadMedia(path: PathString) -> Bool
	{
		// Not available in this implementation
		//
		// Video capture has no media
		return false
	}

	/// Skips to the next media file
	func next()
	{
		// Not available in this implementation
		//
		// Video capture has no media
	}

	/// Skips to the previous media file
	func previous()
	{
		// Not available in this implementation
		//
		// Video capture has no media
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
#endif // USE_MMAL
