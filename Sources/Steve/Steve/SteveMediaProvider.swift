//
//  SteveMediaProvider.swift
//  Steve
//
//  Created by Paul Nettle on 11/7/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Cocoa
import AVFoundation
import Minion
import Seer

/// A Media Provider is an implementation that runs through individual frames of video input either from live video or captured
/// media files such as MP4 or MOV files as well as still images like PNG or JPG files. Frames are then processed through a
/// `MediaConsumer` object (provided at initialization.)
///
/// Implementing the `MediaProvider` protocol requires support for managing media (loading media, jumping to the next/previous
/// media file, basic playback functionality and status information.
///
/// In addition, since it is the `MediaProvider`'s responsibility to process that media through the `MediaConsumer`, the
/// implementation is also required for storing the current `CodeDefinition` used for processing media through the `MediaConsumer`.
final class SteveMediaProvider: MediaProvider
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Class constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Dictionary of pixel buffers that are supported for video decoding
	private let kPixelBufferDict: [String: Any] =
	[
		// 32 bit BGRA
		//kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA

		// Two planes: (1) a byte for each pixel with the Y (luma) value and (2) the Cb and Cr (chroma) values
		kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
	]

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
				singletonInstance = SteveMediaProvider()
			}

			return singletonInstance!
		}
		set
		{
			assert(singletonInstance != nil)
		}
	}

	//
	// AVFoundation video playback
	//

	private var displayLink: CVDisplayLink?
	private var videoOutput = Atomic<AVPlayerItemVideoOutput?>(nil)
	private var playerItem = Atomic<AVPlayerItem?>(nil)
	private var player: AVPlayer?

	//
	// Playback flags & controls
	//

	private var playLastFrameRequested = false

	//
	// Image frames
	//

	private var workImage: LumaBuffer?
	private var lumaBuffer: LumaBuffer?

	/// Media consumer (where our decoded frames are sent for processing)
	private var mediaConsumer: MediaConsumer?

	//
	// Media file & management
	//

	private var	mediaFiles = [PathString]()
	private var currentMediaFileIndex = 2

	// -----------------------------------------------------------------------------------------------------------------------------
	// Media
	// -----------------------------------------------------------------------------------------------------------------------------

	private func scanMediaFiles()
	{
		// Scan for media files
		if let resources = Bundle.main.resourcePath
		{
			let resourcePath = PathString(resources)
			do
			{
				let directoryContents = resourcePath.contentsOfDirectory()
				for entry in directoryContents
				{
					let path = resourcePath + entry
					if isVideoFile(filename: path) || isImageFile(filename: path)
					{
						mediaFiles.append(path)
					}
				}
			}
		}
	}

	private func isLumaFile(filename: PathString) -> Bool
	{
		return filename.lowercased().hasSuffix(".luma")
	}

	private func isVideoFile(filename: PathString) -> Bool
	{
		let lowerName = filename.lowercased()
		for fileType in SteveMediaProvider.videoFileExtensions
		{
			if lowerName.hasSuffix(fileType)
			{
				return true
			}
		}

		return false
	}

	private func isImageFile(filename: PathString) -> Bool
	{
		let lowerName = filename.lowercased()
		for fileType in SteveMediaProvider.imageFileExtensions
		{
			if lowerName.hasSuffix(fileType)
			{
				return true
			}
		}

		return false
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Loading
	// -----------------------------------------------------------------------------------------------------------------------------

	private func loadImage(path: PathString) -> Bool
	{
		gLogger.info("Loading image: \(path.toString().split(on: "/").last ?? "- Unknown -")")

		guard let image = NSImage(contentsOfFile: path.toString())?.cgImage(forProposedRect: nil, context: nil, hints: nil) else
		{
			gLogger.error("Failed to load image")
			return false
		}

		let width = image.width
		let height = image.height

		let imageBuffer = DebugBuffer(width: width, height: height)
		let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo().rawValue).rawValue
		let bytesPerRow = width * 4
		guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return false }
		guard let context = CGContext(data: imageBuffer.buffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else { return false }

		// Clear the buffer
		context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
		context.fill(CGRect(x: 0, y: 0, width: width, height: height))

		// Draw the image to the bitmap context so we can get the raw image data
		context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

		let callback =
		{
			// Store our work image
			self.workImage = LumaBuffer(width: width, height: height)
			do
			{
				try self.workImage?.copy(from: imageBuffer)
			}
			catch
			{
				gLogger.error("Failed to create work image: \(error.localizedDescription)")
			}

			self.onMediaChanged(to: path, withSize: IVector(x: width, y: height))

			// Images only process when a forced frame is requested
			self.playLastFrame()
		}

		if isPlaying
		{
			setPostFrameCallback(callback)
			isPlaying = false
		}
		else
		{
			callback()
		}

		return true
	}

	private func loadLuma(path: PathString)
	{
		// Load the .luma file binary data
		var data = Data()
		guard let image = try? ImageBuffer<Luma>(fromLumaFile: path, userData: &data) else
		{
			gLogger.error("Unable to restore frame, image would not initialize from file: \(path)")
			return
		}

		// Extract the elements from the data
		var offset = data.startIndex
		let end = data.endIndex
		let offsetX = data.subdata(in: Range(uncheckedBounds: (offset, end))).to(type: Int32.self)
		offset += MemoryLayout.size(ofValue: offsetX)
		let offsetY = data.subdata(in: Range(uncheckedBounds: (offset, end))).to(type: Int32.self)
		offset += MemoryLayout.size(ofValue: offsetY)
		let angle = data.subdata(in: Range(uncheckedBounds: (offset, end))).to(type: Real.self)
		offset += MemoryLayout.size(ofValue: angle)

		gLogger.info("Restoring archived frame. Resolution[\(image.width)x\(image.height)] offset[\(offsetX), \(offsetY)] angle[\(angle)]")

		let callback =
		{
			// Swap out the image
			self.workImage = image

			// Notify the media has changed
			self.onMediaChanged(to: path, withSize: IVector(x: image.width, y: image.height))

			// Restore the temporal state
			Config.replayTemporalState = DeckSearch.TemporalState(offset: IVector(x: Int(offsetX), y: Int(offsetY)), angleDegrees: angle)

			// Trigger a play of the frame
			self.playLastFrame()
		}

		if isPlaying
		{
			setPostFrameCallback(callback)
			isPlaying = false
		}
		else
		{
			callback()
		}
	}

	private func loadVideo(path: PathString) -> Bool
	{
		playerItem.mutate { $0 = AVPlayerItem(url: path.toUrl()) }

		if playerItem.value == nil
		{
			gLogger.error("Unable to load video file: \(path)")
			return false
		}

		let videoTracks = playerItem.value!.asset.tracks(withMediaType: AVMediaType.video)
		if videoTracks.count == 0
		{
			gLogger.error("Video file contains no tracks: \(path)")
			return false
		}

		let videoTrack = videoTracks[0]

		let videoSize = videoTrack.naturalSize

		onMediaChanged(to: path, withSize: IVector(x: Int(videoSize.width), y: Int(videoSize.height)))

		player = AVPlayer(playerItem: playerItem.value)
		if player == nil
		{
			gLogger.error("Unable to create AVPlayer object")
			return false
		}

		videoOutput.mutate { $0 = AVPlayerItemVideoOutput(pixelBufferAttributes: kPixelBufferDict) }
		if videoOutput.value == nil
		{
			gLogger.error("Unable to create AVPlayerItemVideoOutput object")
			return false
		}

		// Add the output for this item
		playerItem.value!.add(videoOutput.value!)

		// We don't care about sound
		player!.volume = 0

		// Start playback
		isPlaying = true

		gLogger.info("Loaded video: \(path.toString().split(on: "/").last ?? "- Unknown -")")
		return true
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Video frame management
	// -----------------------------------------------------------------------------------------------------------------------------

	private func initDisplayLink()
	{
		// Our callback
		let callback: CVDisplayLinkOutputCallback =
		{( _: CVDisplayLink, _: UnsafePointer<CVTimeStamp>, inOutputTime: UnsafePointer<CVTimeStamp>, _: CVOptionFlags, _: UnsafeMutablePointer<CVOptionFlags>, displayLinkContext: UnsafeMutableRawPointer? ) -> CVReturn in
			unsafeBitCast(displayLinkContext, to: SteveMediaProvider.self).onDisplayUpdate(inOutputTime: inOutputTime)
			return kCVReturnSuccess
		}

		if CVDisplayLinkCreateWithActiveCGDisplays(&displayLink) != kCVReturnSuccess
		{
			gLogger.error("Unable to create display link")
			return
		}
		if displayLink == nil
		{
			gLogger.error("We didn't get a display link!")
			return
		}
		if CVDisplayLinkSetOutputCallback(displayLink!, callback, Unmanaged.passUnretained(self).toOpaque()) != kCVReturnSuccess
		{
			gLogger.error("Unable to set callback for display link")
			return
		}
		if CVDisplayLinkStart(displayLink!) != kCVReturnSuccess
		{
			gLogger.error("Unable to start display link")
			return
		}
	}

	private func onDisplayUpdate(inOutputTime: UnsafePointer<CVTimeStamp>)
	{
		preFrameCallback?()
		preFrameCallback = nil

		defer
		{
			postFrameCallback?()
			postFrameCallback = nil
		}

		if !PerfTimer.started
		{
			PerfTimer.start()
		}

		let _track_ = PerfTimer.ScopedTrack(name: "Full frame"); _track_.use()

		let mediaSourcePath = PathString(mediaSource)
		if isVideoFile(filename: mediaSourcePath)
		{
			onVideoFrame(inOutputTime: inOutputTime, playLastFrame: playLastFrameRequested)
		}
		else if isImageFile(filename: mediaSourcePath) || isLumaFile(filename: mediaSourcePath)
		{
			onImageFrame(inOutputTime: inOutputTime, playLastFrame: playLastFrameRequested)
		}

		playLastFrameRequested = false

		let _track2_ = PerfTimer.ScopedTrack(name: "Debug"); _track2_.use()
		SteveViewController.instance.updateLog()
	}

	private func onImageFrame(inOutputTime: UnsafePointer<CVTimeStamp>, playLastFrame: Bool)
	{
		// We only render image frames if a frame was forced
		if playLastFrame
		{
			if let workImage = workImage, let codeDefinition = Config.searchCodeDefinition
			{
				// Let time run during our processing... we'll need it for performance times
				PausableTime.unpause()

				let lumaBuffer = LumaBuffer(width: workImage.width, height: workImage.height)
				lumaBuffer.buffer.assign(from: workImage.buffer, count: workImage.width * workImage.height)

				// Process it
				executeWhenNotProcessing
				{
					SteveViewController.instance.mediaConsumer?.processFrame(lumaBuffer: lumaBuffer, codeDefinition: codeDefinition)
				}

				// Okay, stop time again
				PausableTime.pause()
			}
		}
	}

	private func onVideoFrame(inOutputTime: UnsafePointer<CVTimeStamp>, playLastFrame: Bool)
	{
		guard let videoOutput = self.videoOutput.value else { return }

		// Did we reach the end of playback?
		let itemTime = videoOutput.itemTime(for: inOutputTime.pointee)
		if itemTime >= playerItem.value!.duration
		{
			// Disable playback
			isPlaying = false
		}

		// Check for a new frame of video
		let videoStart = PerfTimer.trackBegin()
		if videoOutput.hasNewPixelBuffer(forItemTime: itemTime)
		{
			gLogger.frame("New pixel buffer available at video time: \(itemTime.seconds) seconds")
			if let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
			{
				// Go get the new video image
				workImage = decodeVideoFrame(pixelBuffer: pixelBuffer)
				PerfTimer.trackEnd(name: "Video decode", start: videoStart)

				if let workImage = workImage, let codeDefinition = Config.searchCodeDefinition
				{
					// Reset our frame type flags
					Config.isReplayingFrame = false

					// Process it
					executeWhenNotProcessing
					{
						SteveViewController.instance.mediaConsumer?.processFrame(lumaBuffer: workImage, codeDefinition: codeDefinition)
					}

					// If the scanner has requested a pause, this is where we should comply
					if Config.pauseRequested
					{
						isPlaying = false
						Config.pauseRequested = false
					}

					// If we're in step frame mode, go request another frame
					if isPlaying && isFullSpeedMode
					{
						step(by: 1)
					}
				}
				else
				{
					gLogger.warn("Unable to decode video frame")
				}
			}
			else
			{
				gLogger.warn("Unable to copy pixel buffer from new frame of video")
				PerfTimer.trackEnd(name: "Video decode", start: videoStart)
			}
		}
		else
		{
			PerfTimer.trackEnd(name: "Video decode", start: videoStart)

			// We're not officially playing - are we being asked to play the last frame?
			if playLastFrame
			{
				// If we have one, render the last frame we got
				if let workImage = workImage, let codeDefinition = Config.searchCodeDefinition
				{
					// Reset our frame type flags
					Config.isReplayingFrame = true

					// Let time run during our processing... we'll need it for performance times
					PausableTime.unpause()

					// Process it
					executeWhenNotProcessing
					{
						SteveViewController.instance.mediaConsumer?.processFrame(lumaBuffer: workImage, codeDefinition: codeDefinition)
					}

					// Okay, stop time again
					PausableTime.pause()
				}
			}
		}
	}

	private func decodeVideoFrame(pixelBuffer: CVPixelBuffer) -> LumaBuffer?
	{
		// Lock it
		if CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == kCVReturnSuccess
		{
			defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

			// Get the base address of the luma plane
			if let lumaBaseAddress: UnsafeMutableRawPointer = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
			{
				// Update the pixels in the frame buffer
				let width = CVPixelBufferGetWidth(pixelBuffer)
				let height = CVPixelBufferGetHeight(pixelBuffer)

				// Allocate a new luma buffer if we need to
				if lumaBuffer == nil || lumaBuffer!.width != width || lumaBuffer!.height != height
				{
					lumaBuffer = LumaBuffer(width: width, height: height)
				}

				let format = CVPixelBufferGetPixelFormatType(pixelBuffer)

				if format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
				{
					let byteBuffer = lumaBaseAddress.assumingMemoryBound(to: UInt8.self)
					lumaBuffer?.copy(from: byteBuffer, width: width, height: height)
				}
				else if format == kCVPixelFormatType_32BGRA
				{
					let dwordBuffer = lumaBaseAddress.assumingMemoryBound(to: UInt32.self)
					let debugBuffer = DebugBuffer(width: width, height: height, buffer: dwordBuffer)
					((try? lumaBuffer?.copy(from: debugBuffer)) as ()??)
				}
				else
				{
					gLogger.error("Unsupported frame format: \(formatTypeString(for: pixelBuffer)) - \(formatDescription(for: pixelBuffer))")
				}
			}
			else
			{
				gLogger.error("Unable to get plane 0")
			}
		}
		else
		{
			gLogger.error("Unable to lock pixel buffer")
		}

		return lumaBuffer
	}

	private func formatTypeString(for pixelBuffer: CVPixelBuffer) -> String
	{
		let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
		switch format
		{
			case kCVPixelFormatType_1Monochrome: return "kCVPixelFormatType_1Monochrome"
			case kCVPixelFormatType_2Indexed: return "kCVPixelFormatType_2Indexed"
			case kCVPixelFormatType_4Indexed: return "kCVPixelFormatType_4Indexed"
			case kCVPixelFormatType_8Indexed: return "kCVPixelFormatType_8Indexed"
			case kCVPixelFormatType_1IndexedGray_WhiteIsZero: return "kCVPixelFormatType_1IndexedGray_WhiteIsZero"
			case kCVPixelFormatType_2IndexedGray_WhiteIsZero: return "kCVPixelFormatType_2IndexedGray_WhiteIsZero"
			case kCVPixelFormatType_4IndexedGray_WhiteIsZero: return "kCVPixelFormatType_4IndexedGray_WhiteIsZero"
			case kCVPixelFormatType_8IndexedGray_WhiteIsZero: return "kCVPixelFormatType_8IndexedGray_WhiteIsZero"
			case kCVPixelFormatType_16BE555: return "kCVPixelFormatType_16BE555"
			case kCVPixelFormatType_16LE555: return "kCVPixelFormatType_16LE555"
			case kCVPixelFormatType_16LE5551: return "kCVPixelFormatType_16LE5551"
			case kCVPixelFormatType_16BE565: return "kCVPixelFormatType_16BE565"
			case kCVPixelFormatType_16LE565: return "kCVPixelFormatType_16LE565"
			case kCVPixelFormatType_24RGB: return "kCVPixelFormatType_24RGB"
			case kCVPixelFormatType_24BGR: return "kCVPixelFormatType_24BGR"
			case kCVPixelFormatType_32ARGB: return "kCVPixelFormatType_32ARGB"
			case kCVPixelFormatType_32BGRA: return "kCVPixelFormatType_32BGRA"
			case kCVPixelFormatType_32ABGR: return "kCVPixelFormatType_32ABGR"
			case kCVPixelFormatType_32RGBA: return "kCVPixelFormatType_32RGBA"
			case kCVPixelFormatType_64ARGB: return "kCVPixelFormatType_64ARGB"
			case kCVPixelFormatType_48RGB: return "kCVPixelFormatType_48RGB"
			case kCVPixelFormatType_32AlphaGray: return "kCVPixelFormatType_32AlphaGray"
			case kCVPixelFormatType_16Gray: return "kCVPixelFormatType_16Gray"
			case kCVPixelFormatType_30RGB: return "kCVPixelFormatType_30RGB"
			case kCVPixelFormatType_422YpCbCr8: return "kCVPixelFormatType_422YpCbCr8"
			case kCVPixelFormatType_4444YpCbCrA8: return "kCVPixelFormatType_4444YpCbCrA8"
			case kCVPixelFormatType_4444YpCbCrA8R: return "kCVPixelFormatType_4444YpCbCrA8R"
			case kCVPixelFormatType_4444AYpCbCr8: return "kCVPixelFormatType_4444AYpCbCr8"
			case kCVPixelFormatType_4444AYpCbCr16: return "kCVPixelFormatType_4444AYpCbCr16"
			case kCVPixelFormatType_444YpCbCr8: return "kCVPixelFormatType_444YpCbCr8"
			case kCVPixelFormatType_422YpCbCr16: return "kCVPixelFormatType_422YpCbCr16"
			case kCVPixelFormatType_422YpCbCr10: return "kCVPixelFormatType_422YpCbCr10"
			case kCVPixelFormatType_444YpCbCr10: return "kCVPixelFormatType_444YpCbCr10"
			case kCVPixelFormatType_420YpCbCr8Planar: return "kCVPixelFormatType_420YpCbCr8Planar"
			case kCVPixelFormatType_420YpCbCr8PlanarFullRange: return "kCVPixelFormatType_420YpCbCr8PlanarFullRange"
			case kCVPixelFormatType_422YpCbCr_4A_8BiPlanar: return "kCVPixelFormatType_422YpCbCr_4A_8BiPlanar"
			case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: return "kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange"
			case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: return "kCVPixelFormatType_420YpCbCr8BiPlanarFullRange"
			case kCVPixelFormatType_422YpCbCr8_yuvs: return "kCVPixelFormatType_422YpCbCr8_yuvs"
			case kCVPixelFormatType_422YpCbCr8FullRange: return "kCVPixelFormatType_422YpCbCr8FullRange"
			case kCVPixelFormatType_OneComponent8: return "kCVPixelFormatType_OneComponent8"
			case kCVPixelFormatType_TwoComponent8: return "kCVPixelFormatType_TwoComponent8"
			case kCVPixelFormatType_30RGBLEPackedWideGamut: return "kCVPixelFormatType_30RGBLEPackedWideGamut"
			case kCVPixelFormatType_ARGB2101010LEPacked: return "kCVPixelFormatType_ARGB2101010LEPacked"
			case kCVPixelFormatType_OneComponent16Half: return "kCVPixelFormatType_OneComponent16Half"
			case kCVPixelFormatType_OneComponent32Float: return "kCVPixelFormatType_OneComponent32Float"
			case kCVPixelFormatType_TwoComponent16Half: return "kCVPixelFormatType_TwoComponent16Half"
			case kCVPixelFormatType_TwoComponent32Float: return "kCVPixelFormatType_TwoComponent32Float"
			case kCVPixelFormatType_64RGBAHalf: return "kCVPixelFormatType_64RGBAHalf"
			case kCVPixelFormatType_128RGBAFloat: return "kCVPixelFormatType_128RGBAFloat"
			case kCVPixelFormatType_14Bayer_GRBG: return "kCVPixelFormatType_14Bayer_GRBG"
			case kCVPixelFormatType_14Bayer_RGGB: return "kCVPixelFormatType_14Bayer_RGGB"
			case kCVPixelFormatType_14Bayer_BGGR: return "kCVPixelFormatType_14Bayer_BGGR"
			case kCVPixelFormatType_14Bayer_GBRG: return "kCVPixelFormatType_14Bayer_GBRG"
			case kCVPixelFormatType_DisparityFloat16: return "kCVPixelFormatType_DisparityFloat16"
			case kCVPixelFormatType_DisparityFloat32: return "kCVPixelFormatType_DisparityFloat32"
			case kCVPixelFormatType_DepthFloat16: return "kCVPixelFormatType_DepthFloat16"
			case kCVPixelFormatType_DepthFloat32: return "kCVPixelFormatType_DepthFloat32"
			case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange: return "kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange"
			case kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange: return "kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange"
			case kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange: return "kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange"
			case kCVPixelFormatType_420YpCbCr10BiPlanarFullRange: return "kCVPixelFormatType_420YpCbCr10BiPlanarFullRange"
			case kCVPixelFormatType_422YpCbCr10BiPlanarFullRange: return "kCVPixelFormatType_422YpCbCr10BiPlanarFullRange"
			case kCVPixelFormatType_444YpCbCr10BiPlanarFullRange: return "kCVPixelFormatType_444YpCbCr10BiPlanarFullRange"
			default: return "Unknown (\(String(format: "%08X", format)))"
		}
	}

	private func formatDescription(for pixelBuffer: CVPixelBuffer) -> String
	{
		let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
		switch format
		{
			case kCVPixelFormatType_1Monochrome: return "1 bit indexed"
			case kCVPixelFormatType_2Indexed: return "2 bit indexed"
			case kCVPixelFormatType_4Indexed: return "4 bit indexed"
			case kCVPixelFormatType_8Indexed: return "8 bit indexed"
			case kCVPixelFormatType_1IndexedGray_WhiteIsZero: return "1 bit indexed gray, white is zero"
			case kCVPixelFormatType_2IndexedGray_WhiteIsZero: return "2 bit indexed gray, white is zero"
			case kCVPixelFormatType_4IndexedGray_WhiteIsZero: return "4 bit indexed gray, white is zero"
			case kCVPixelFormatType_8IndexedGray_WhiteIsZero: return "8 bit indexed gray, white is zero"
			case kCVPixelFormatType_16BE555: return "16 bit BE RGB 555"
			case kCVPixelFormatType_16LE555: return "16 bit LE RGB 555"
			case kCVPixelFormatType_16LE5551: return "16 bit LE RGB 5551"
			case kCVPixelFormatType_16BE565: return "16 bit BE RGB 565"
			case kCVPixelFormatType_16LE565: return "16 bit LE RGB 565"
			case kCVPixelFormatType_24RGB: return "24 bit RGB"
			case kCVPixelFormatType_24BGR: return "24 bit BGR"
			case kCVPixelFormatType_32ARGB: return "32 bit ARGB"
			case kCVPixelFormatType_32BGRA: return "32 bit BGRA"
			case kCVPixelFormatType_32ABGR: return "32 bit ABGR"
			case kCVPixelFormatType_32RGBA: return "32 bit RGBA"
			case kCVPixelFormatType_64ARGB: return "64 bit ARGB, 16-bit big-endian samples"
			case kCVPixelFormatType_48RGB: return "48 bit RGB, 16-bit big-endian samples"
			case kCVPixelFormatType_32AlphaGray: return "32 bit AlphaGray, 16-bit big-endian samples, black is zero"
			case kCVPixelFormatType_16Gray: return "16 bit Grayscale, 16-bit big-endian samples, black is zero"
			case kCVPixelFormatType_30RGB: return "30 bit RGB, 10-bit big-endian samples, 2 unused padding bits (at least significant end)."
			case kCVPixelFormatType_422YpCbCr8: return "Component Y'CbCr 8-bit 4:2:2, ordered Cb Y'0 Cr Y'1"
			case kCVPixelFormatType_4444YpCbCrA8: return "Component Y'CbCrA 8-bit 4:4:4:4, ordered Cb Y' Cr A"
			case kCVPixelFormatType_4444YpCbCrA8R: return "Component Y'CbCrA 8-bit 4:4:4:4, rendering format. full range alpha, zero biased YUV, ordered A Y' Cb Cr"
			case kCVPixelFormatType_4444AYpCbCr8: return "Component Y'CbCrA 8-bit 4:4:4:4, ordered A Y' Cb Cr, full range alpha, video range Y'CbCr."
			case kCVPixelFormatType_4444AYpCbCr16: return "Component Y'CbCrA 16-bit 4:4:4:4, ordered A Y' Cb Cr, full range alpha, video range Y'CbCr, 16-bit little-endian samples."
			case kCVPixelFormatType_444YpCbCr8: return "Component Y'CbCr 8-bit 4:4:4"
			case kCVPixelFormatType_422YpCbCr16: return "Component Y'CbCr 10,12,14,16-bit 4:2:2"
			case kCVPixelFormatType_422YpCbCr10: return "Component Y'CbCr 10-bit 4:2:2"
			case kCVPixelFormatType_444YpCbCr10: return "Component Y'CbCr 10-bit 4:4:4"
			case kCVPixelFormatType_420YpCbCr8Planar: return "Planar Component Y'CbCr 8-bit 4:2:0.  baseAddr points to a big-endian CVPlanarPixelBufferInfo_YCbCrPlanar struct"
			case kCVPixelFormatType_420YpCbCr8PlanarFullRange: return "Planar Component Y'CbCr 8-bit 4:2:0, full range.  baseAddr points to a big-endian CVPlanarPixelBufferInfo_YCbCrPlanar struct"
			case kCVPixelFormatType_422YpCbCr_4A_8BiPlanar: return "First plane: Video-range Component Y'CbCr 8-bit 4:2:2, ordered Cb Y'0 Cr Y'1; second plane: alpha 8-bit 0-255"
			case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: return "Bi-Planar Component Y'CbCr 8-bit 4:2:0, video-range (luma=[16,235] chroma=[16,240]).  baseAddr points to a big-endian CVPlanarPixelBufferInfo_YCbCrBiPlanar struct"
			case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: return "Bi-Planar Component Y'CbCr 8-bit 4:2:0, full-range (luma=[0,255] chroma=[1,255]).  baseAddr points to a big-endian CVPlanarPixelBufferInfo_YCbCrBiPlanar struct"
			case kCVPixelFormatType_422YpCbCr8_yuvs: return "Component Y'CbCr 8-bit 4:2:2, ordered Y'0 Cb Y'1 Cr"
			case kCVPixelFormatType_422YpCbCr8FullRange: return "Component Y'CbCr 8-bit 4:2:2, full range, ordered Y'0 Cb Y'1 Cr"
			case kCVPixelFormatType_OneComponent8: return "8 bit one component, black is zero"
			case kCVPixelFormatType_TwoComponent8: return "8 bit two component, black is zero"
			case kCVPixelFormatType_30RGBLEPackedWideGamut: return "Little-endian RGB101010, 2 MSB are zero, wide-gamut (384-895)"
			case kCVPixelFormatType_ARGB2101010LEPacked: return "Little-endian ARGB2101010 full-range ARGB"
			case kCVPixelFormatType_OneComponent16Half: return "16 bit one component IEEE half-precision float, 16-bit little-endian samples"
			case kCVPixelFormatType_OneComponent32Float: return "32 bit one component IEEE float, 32-bit little-endian samples"
			case kCVPixelFormatType_TwoComponent16Half: return "16 bit two component IEEE half-precision float, 16-bit little-endian samples"
			case kCVPixelFormatType_TwoComponent32Float: return "32 bit two component IEEE float, 32-bit little-endian samples"
			case kCVPixelFormatType_64RGBAHalf: return "64 bit RGBA IEEE half-precision float, 16-bit little-endian samples"
			case kCVPixelFormatType_128RGBAFloat: return "128 bit RGBA IEEE float, 32-bit little-endian samples"
			case kCVPixelFormatType_14Bayer_GRBG: return "Bayer 14-bit Little-Endian, packed in 16-bits, ordered G R G R... alternating with B G B G..."
			case kCVPixelFormatType_14Bayer_RGGB: return "Bayer 14-bit Little-Endian, packed in 16-bits, ordered R G R G... alternating with G B G B..."
			case kCVPixelFormatType_14Bayer_BGGR: return "Bayer 14-bit Little-Endian, packed in 16-bits, ordered B G B G... alternating with G R G R..."
			case kCVPixelFormatType_14Bayer_GBRG: return "Bayer 14-bit Little-Endian, packed in 16-bits, ordered G B G B... alternating with R G R G..."
			case kCVPixelFormatType_DisparityFloat16: return "IEEE754-2008 binary16 (half float), describing the normalized shift when comparing two images. Units are 1/meters: ( pixelShift / (pixelFocalLength * baselineInMeters) )"
			case kCVPixelFormatType_DisparityFloat32: return "IEEE754-2008 binary32 float, describing the normalized shift when comparing two images. Units are 1/meters: ( pixelShift / (pixelFocalLength * baselineInMeters) )"
			case kCVPixelFormatType_DepthFloat16: return "IEEE754-2008 binary16 (half float), describing the depth (distance to an object) in meters"
			case kCVPixelFormatType_DepthFloat32: return "IEEE754-2008 binary32 float, describing the depth (distance to an object) in meters"
			case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange: return "2 plane YCbCr10 4:2:0, each 10 bits in the MSBs of 16bits, video-range (luma=[64,940] chroma=[64,960])"
			case kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange: return "2 plane YCbCr10 4:2:2, each 10 bits in the MSBs of 16bits, video-range (luma=[64,940] chroma=[64,960])"
			case kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange: return "2 plane YCbCr10 4:4:4, each 10 bits in the MSBs of 16bits, video-range (luma=[64,940] chroma=[64,960])"
			case kCVPixelFormatType_420YpCbCr10BiPlanarFullRange: return "2 plane YCbCr10 4:2:0, each 10 bits in the MSBs of 16bits, full-range (Y range 0-1023)"
			case kCVPixelFormatType_422YpCbCr10BiPlanarFullRange: return "2 plane YCbCr10 4:2:2, each 10 bits in the MSBs of 16bits, full-range (Y range 0-1023)"
			case kCVPixelFormatType_444YpCbCr10BiPlanarFullRange: return "2 plane YCbCr10 4:4:4, each 10 bits in the MSBs of 16bits, full-range (Y range 0-1023)"
			default: return "Unknown"
		}
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
	static var videoFileExtensions: [String] { return ["mov", "mp4", "m4v"] }

	/// Array of supported media file extensions for image formats
	static var imageFileExtensions: [String] { return ["png", "jpg", "jpeg", "luma"] }

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
	var isPlaying: Bool
	{
		get
		{
			return isPlaying_.value
		}
		set
		{
			isPlaying_.value = newValue
			if isPlaying
			{
				// If we are in full-speed mode, don't actually set the player to play (full-speed mode will manage frame stepping)
				//
				// See `isFullSpeedMode` mode for complimentary functionality
				player?.rate = isFullSpeedMode ? 0 : 1
				PausableTime.unpause()

				// If we're in full-speed mode, prime it by stepping forward for the first frame
				if isFullSpeedMode { step(by: 1) }
			}
			else
			{
				player?.rate = 0
				PausableTime.pause()
			}
		}
	}
	private var isPlaying_ = AtomicFlag()

	/// Returns true if the current frame is being replayed
	var isReplayingFrame: Bool
	{
		return Config.isReplayingFrame
	}

	/// Returns true if in full-speed mode (i.e., processing frames as quickly as possible.)
	///
	/// This is not likely useful for anything but video file source media, in which case frames are decoded/processed from the
	/// video as fast as the CPU will allow, ignoring the framerate stored in the video itself.
	var isFullSpeedMode: Bool = true
	{
		didSet
		{
			// If we are entring full-speed mode, we always turn off the video playback rate since full-speed mode manages frame
			// stepping for us
			if isFullSpeedMode
			{
				player?.rate = 0

				// Prime it by stepping forward for the first frame
				if isPlaying { step(by: 1) }
			}
			// We are leaving full-speed mode. If the play state is on, make sure the video playback rate is set appropriately
			else if isPlaying
			{
				player?.rate = 1
			}
		}
	}

	/// The name of the current video source
	///
	/// This should return an empty string if no video source is active, or the strigg `Camera` for live video.
	var mediaSource: String
	{
		get
		{
			return mediaSource_.value
		}
		set
		{
			mediaSource_.mutate { $0 = newValue }
		}
	}
	private var mediaSource_ = Atomic<String>("")

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a MediaProvider
	private init()
	{
		scanMediaFiles()
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

		if mediaFiles.count == 0
		{
			gLogger.error("No media files found")
			return
		}

		// Load the media
		currentMediaFileIndex -= 1
		next()

		// Setup our display link
		initDisplayLink()
	}

	/// Restart the current media file at the beginning
	func restart()
	{
		if let player = player
		{
			player.seek(to: CMTime(seconds: 0, preferredTimescale: 30))
			isPlaying = true
		}
	}

	/// Play the last played frame again, processing it as if it is a new frame of input
	func playLastFrame()
	{
		if !isPlaying
		{
			playLastFrameRequested = true
		}
	}

	/// Waits for the media provider to shut down
	func waitUntilStopped()
	{
		gLogger.error("SteveMediaProvider does not support waitUntilStopped()")
		return
	}

	/// Play the last played frame again, re-processing it exactly as it was previously
	///
	/// This is specifically useful for debugging code that with temporal considerations.
	func replayLastFrame() -> Bool
	{
		if let workImage = workImage, let codeDefinition = Config.searchCodeDefinition
		{
			let lumaBuffer = LumaBuffer(width: workImage.width, height: workImage.height)
			lumaBuffer.buffer.assign(from: workImage.buffer, count: workImage.width * workImage.height)

			// Process it
			Config.isReplayingFrame = true
			executeWhenNotProcessing
			{
				SteveViewController.instance.mediaConsumer?.processFrame(lumaBuffer: lumaBuffer, codeDefinition: codeDefinition)
			}
			Config.isReplayingFrame = false

			return true
		}
		else
		{
			return false
		}
	}

	/// Step the video by `count` frames
	///
	/// If `count` is a positive value, the step will be forward. Conversely, if `count` is a negative value, the step will be in
	/// reverse. Calling with a `count` of `0` will do nothing.
	func step(by count: Int)
	{
		if let playerItem = playerItem.value
		{
			if count > 0 && playerItem.canStepForward
			{
				playerItem.step(byCount: count)
			}
			else if count < 0 && playerItem.canStepBackward
			{
				playerItem.step(byCount: count)
			}
		}
	}

	/// Load an image or video file at the given `path`.
	///
	/// The media at `path` must be of a supported media type (see `videoFileExtensions` and `imageFileExtensions`.)
	func loadMedia(path: PathString) -> Bool
	{
		return executeWhenNotProcessing
		{
			return self.internalLoadMedia(path: path)
		}
	}

	/// Internal implementation for the `loadMedia` function, containing most (all?) of the actual implementation
	private func internalLoadMedia(path: PathString) -> Bool
	{
		var found = false
		for def in CodeDefinition.codeDefinitions
		{
			if path.lastComponent()?.hasPrefix("\(def.format.name).") ?? false
			{
				found = true
				Config.searchCodeDefinition = def
				break
			}
		}

		if !found
		{
			gLogger.warn("Code definition not found in filename '\(path.lastComponent() ?? "unknown")', maintaining current definition")
		}

		var result = false
		if isLumaFile(filename: path)
		{
			loadLuma(path: path)
			result = true
		}
		else if isVideoFile(filename: path)
		{
			result = loadVideo(path: path)
		}
		else if isImageFile(filename: path)
		{
			result = loadImage(path: path)
		}

		if result
		{
			mediaSource = path.toString()
		}
		else
		{
			mediaSource = "Unsupported: \(path)"
		}

		return result
	}

	/// Skips to the next media file
	func next()
	{
		if mediaFiles.count > 0
		{
			repeat
			{
				currentMediaFileIndex += 1
				if currentMediaFileIndex >= mediaFiles.count
				{
					currentMediaFileIndex -= mediaFiles.count
				}
			} while !loadMedia(path: mediaFiles[currentMediaFileIndex])
		}
	}

	/// Skips to the previous media file
	func previous()
	{
		if mediaFiles.count > 0
		{
			repeat
			{
				currentMediaFileIndex -= 1
				if currentMediaFileIndex < 0
				{
					currentMediaFileIndex += mediaFiles.count
				}
			} while !loadMedia(path: mediaFiles[currentMediaFileIndex])
		}
	}

	/// Stores the last frame as a `LUMA` image file, containing temporal information for accurate replay of that frame
	func archiveFrame(baseName: String, async: Bool) -> Bool
	{
		if let workImage = workImage
		{
			do
			{
				try workImage.writeLuma(to: baseName, async: async)
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
			return false
		}
	}

	/// This method must be called whenever media is changed, in order to allow the system to manage a new input resolution
	func onMediaChanged(to path: PathString, withSize size: IVector)
	{
		(self as MediaProvider).onMediaChanged(to: path, withSize: size)

		DispatchQueue.main.async
		{
			SteveViewController.instance.view.window?.setTitleWithRepresentedFilename(path.toString())
			SteveViewController.instance.view.window?.title = path.lastComponent() ?? ""
			SteveViewController.instance.view.window!.title += "   ::   \(size.x) x \(size.y)"
			SteveViewController.instance.view.window!.title += "   ::   Steve[\(SteveVersion)]"
			SteveViewController.instance.view.window!.title += "   ::   Seer[\(SeerVersion)]"
			SteveViewController.instance.view.window!.title += "   ::   Minion[\(MinionVersion)]"
		}
	}
}
