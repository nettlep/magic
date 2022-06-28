//
//  MediaProvider.swift
//  Seer
//
//  Created by Paul Nettle on 04/18/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#if os(iOS)
import MinionIOS
#else
import Minion
#endif

/// A Media Provider is an implementation that runs through individual frames of video input either from live video or captured
/// media files such as MP4 or MOV files as well as still images like PNG or JPG files. Frames are then processed through a
/// `MediaConsumer` object (provided at initialization.)
///
/// Implementing the `MediaProvider` protocol requires support for managing media (loading media, jumping to the next/previous
/// media file, basic playback functionality and status information.
///
/// In addition, since it is the `MediaProvider`'s responsibility to process that media through the `MediaConsumer`, the
/// implementation is also required for storing the current `CodeDefinition` used for processing media through the `MediaConsumer`.
public protocol MediaProvider
{
	/// Array of supported media file extensions for video formats
	static var videoFileExtensions: [String] { get }

	/// Array of supported media file extensions for image formats
	static var imageFileExtensions: [String] { get }

	/// Pre-frame callback
	///
	/// Pre-frame callbacks are blocks that are called prior to processing a video frame through the `MediaConsumer`. This is a
	/// one-time call and must be set for each frame.
	///
	/// Only one callback can be associated at a given time. Therefore, setting two callbacks would result in the first callback
	/// being overridden by the first and only one callback (the second) being called.
	func setPreFrameCallback(_ callback: @escaping () -> Void)

	/// Post-frame callback
	///
	/// Post-frame callbacks are blocks that are called after processing a video frame through the `MediaConsumer`. This is a
	/// one-time call and must be set for each frame.
	///
	/// Only one callback can be associated at a given time. Therefore, setting two callbacks would result in the first callback
	/// being overridden by the first and only one callback (the second) being called.
	func setPostFrameCallback(_ callback: @escaping () -> Void)

	/// Returns true if playback is active
	var isPlaying: Bool { get set }

	/// Returns true if the current frame is being replayed
	var isReplayingFrame: Bool { get }

	/// Returns true if in full-speed mode (i.e., processing frames as quickly as possible.)
	///
	/// This is not likely useful for anything but video file source media, in which case frames are decoded/processed from the
	/// video as fast as the CPU will allow, ignoring the framerate stored in the video itself.
	var isFullSpeedMode: Bool { get set }

	/// The name of the current video source
	///
	/// This should return an empty string if no video source is active, or the strigg `Camera` for live video.
	var mediaSource: String { get }

	/// This method should be implemented as:
	///
	///     public func executeWhenNotProcessing<Result>(block: @escaping () -> Result) -> Result
	///     {
	///         return mediaConsumer(block)
	///     }
	///
	/// No default implementation is provided because it is up to the owner to manage the storage of the media consumer, and hence,
	/// it is not available to this protocol.
	func executeWhenNotProcessing<Result>(_ block: @escaping () -> Result) -> Result

	/// Start playback of the first media file
	func start(mediaConsumer: MediaConsumer)

	/// Restart the current media file at the beginning
	func restart()

	/// Waits for the media provider to shut down
	///
	/// Generally, this should be implemented using a `DispatchSemaphore` that is signalled when the provider is completely stopped
	func waitUntilStopped()

	/// Play the last played frame again, processing it as if it is a new frame of input
	func playLastFrame()

	/// Play the last played frame again, re-processing it exactly as it was previously
	///
	/// This is specifically useful for debugging code that with temporal considerations.
	func replayLastFrame() -> Bool

	/// Step the video by `count` frames
	///
	/// If `count` is a positive value, the step will be forward. Conversely, if `count` is a negative value, the step will be in
	/// reverse. Calling with a `count` of `0` will do nothing.
	func step(by count: Int)

	/// Load an image or video file at the given `path`.
	///
	/// The media at `path` must be of a supported media type (see `videoFileExtensions` and `imageFileExtensions`.)
	func loadMedia(path: PathString) -> Bool

	/// Skips to the next media file
	func next()

	/// Skips to the previous media file
	func previous()

	/// Stores the last frame as a `LUMA` image file, containing temporal information for accurate replay of that frame
	func archiveFrame(baseName: String, async: Bool) -> Bool
}

extension MediaProvider
{
	/// This method must be called whenever media is changed, in order to allow the system to manage a new input resolution
	public func onMediaChanged(to path: PathString, withSize size: IVector)
	{
	}
}
