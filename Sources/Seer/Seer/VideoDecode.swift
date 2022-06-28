//
//  VideoDecode.swift
//  Seer
//
//  Created by Paul Nettle on 6/8/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#if os(macOS) || os(Linux)

import C_Libav
import Minion

// ---------------------------------------------------------------------------------------------------------------------------------
// Globals
// ---------------------------------------------------------------------------------------------------------------------------------

/// Video capture management class
///
/// Performs initialization and capture of live video data
public class VideoDecode
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Have we been initialized?
	private var mVideoInitialized = false

	/// Frame settings
	private var mVideoUrl = PathString()

	/// Decoding parameters
	private var mpFormatCtx: UnsafeMutablePointer<AVFormatContext>?
#if os(macOS)
	private var mpCodec: UnsafePointer<AVCodec>?
#endif
#if os(Linux)
    private var mpCodec: UnsafeMutablePointer<AVCodec>?
#endif
	private var mpCodecCtx: UnsafeMutablePointer<AVCodecContext>?
	private var mpFrame: UnsafeMutablePointer<AVFrame>?
	private var mPacket = AVPacket()
	private var mVideoStreamIndex = 0

	/// Decoding stats
	private var mDecodedFrameCount = 0
	private var mNonVideoFrameCount = 0

	/// Tracks our one-time initialization
	private static var oneTimeInitialized = false

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Public initializer for the VideoDecode object
	public init()
	{

	}

	/// Performs various one-time initializations.
	///
	/// Calling this method multiple times will do no harm as this method will only perform those initializations which have not yet
	/// been performed (i.e., those that failed in previous attempts.)
	///
	/// Throws VideoException on error
	private func oneTimeInit()
	{
		if !VideoDecode.oneTimeInitialized
		{
			gLogger.debug("Performing one-time initialization of libav")

			// Register all the formats
			//av_register_all() // Deprecated in FFmpeg 4.0

			// Register all the codecs
			//avcodec_register_all() // Deprecated in FFmpeg 4.0
			avformat_network_init()

			VideoDecode.oneTimeInitialized = true
		}
	}

	/// Destruction
	deinit
	{
		stop()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Decode control
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Causes video decoding of the requested `videoUrl` to be initialized
	///
	/// Usage:
	///
	///     - To decode and receive video frames, call `decodeFrame()`
	///     - To stop decoding, call `stop()` or wait for `decodeFrame()` to return `nil`
	///
	/// Notes:
	///
	///     Be sure to format `videoUrl` as a URL. For example: file://video.mp4
	///
	/// Throws VideoException on error
	public func start(path: PathString) -> Bool
	{
		gLogger.video("Initializing a video decode with URL: \(path)")

		// Ensure we've had our one-time initialization performed
		oneTimeInit()

		// If we're already initialized, uninitialize now
		stop()

		// Initialize our internal values
		mVideoUrl = path

		do
		{
			// Opening input file with avformat
			gLogger.video("Opening input URL: \(mVideoUrl)")

			// Use AVFormatContext to open the file to determine its format and read it
			if avformat_open_input(&mpFormatCtx, mVideoUrl.toString(), nil, nil) < 0
			{
				throw VideoDecodeError.IO("Unable to open input URL: \(mVideoUrl)")
			}

			gLogger.debug("  >> Getting stream information")

			// Retrieve stream information
			if avformat_find_stream_info(mpFormatCtx, nil) < 0
			{
	 			throw VideoDecodeError.Stream("Unable to find stream information from source: \(mVideoUrl)")
			}

			// Dump the stream information
			// av_dump_format(mpFormatCtx, 0, mVideoUrl.toString(), 0)

			guard let formatCtx = mpFormatCtx?.pointee else
			{
	 			throw VideoDecodeError.Stream("Unable to get stream format context from source: \(mVideoUrl)")
			}

			// Find the first video stream
			mVideoStreamIndex = -1
			var videoStreamCount = 0
			for i in 0..<Int(formatCtx.nb_streams)
			{
				if formatCtx.streams[i]?.pointee.codecpar.pointee.codec_type == AVMEDIA_TYPE_VIDEO
				{
					if mVideoStreamIndex == -1
					{
						mVideoStreamIndex = i
					}
					videoStreamCount += 1
				}
			}

			if mVideoStreamIndex == -1
			{
				throw VideoDecodeError.Stream("Unable to find video stream")
			}

			gLogger.debug("  >> Found \(videoStreamCount) video stream(s), reading from video stream index: \(mVideoStreamIndex)")

			gLogger.debug("  >> Transferring codec parameters")

			guard let parameters = formatCtx.streams[mVideoStreamIndex]?.pointee.codecpar else
			{
				throw VideoDecodeError.Stream("Unable to get video stream's codec parameters")
			}

			// Find the decoder for the video stream based on the video stream's codec
			mpCodec = avcodec_find_decoder(parameters.pointee.codec_id)
			if mpCodec == nil
			{
				throw VideoDecodeError.Codec("Unsupported codec")
			}

			mpCodecCtx = avcodec_alloc_context3(mpCodec)
			if avcodec_parameters_to_context(mpCodecCtx, parameters) < 0
			{
				// avcodec_parameters_free(&parameters)
				throw VideoDecodeError.Codec("Failed to transfer parameters")
			}

			gLogger.debug("  >> Opening the codec")

			// Open codec
			if avcodec_open2(mpCodecCtx, mpCodec, nil) < 0
			{
				throw VideoDecodeError.Codec("Could not open codec")
			}

			// Setup our frame
			mpFrame = av_frame_alloc()

			gLogger.video("  >> Decoding video...")

			mVideoInitialized = true
		}
		catch
		{
			// Log the error
			gLogger.error("ERROR: Caught VideoDecodeError: \(error.localizedDescription)")
			return false
		}

		// Reset our frame counts
		mDecodedFrameCount = 0
		mNonVideoFrameCount = 0

		return mVideoInitialized
	}

	/// Decode and return the next frame of video data
	///
	/// Returns a valid frame of video or `nil` in the following cases:
	///
	///     * The decoder was not initialized
	///     * The end of the video was reached
	///     * An error occurs
	///
	/// In any case, if this method returns `nil`, then the video decoder is automatically stopped. When this happens, it is
	/// unnecessary (but safe) to call `stop()`.
	public func frame() -> LumaBuffer?
	{
		// We must be initialized
		if !mVideoInitialized { return nil }

		while av_read_frame(mpFormatCtx, &mPacket) >= 0
		{
			do
			{
				// Is this a packet from the video stream?
				if Int(mPacket.stream_index) == mVideoStreamIndex
				{
					// Decode a single video frame

					let sendRes = avcodec_send_packet(mpCodecCtx, &mPacket)
					if sendRes != 0
					{
						throw VideoDecodeError.Frame("Error sending packet for frame decode (\(sendRes))")
					}

					let recvRes = avcodec_receive_frame(mpCodecCtx, mpFrame)
					if recvRes != 0
					{
						throw VideoDecodeError.Frame("Error receiving frame for decode (\(recvRes))")
					}

					mDecodedFrameCount += 1

					guard let codecCtx = mpCodecCtx?.pointee else
					{
						throw VideoDecodeError.Frame("Frame decode produced no usable codec context")
					}

					guard let frame = mpFrame?.pointee else
					{
						throw VideoDecodeError.Frame("Frame decode produced no usable frame")
					}

					// Unref the packet that was allocated by av_read_frame
					av_packet_unref(&mPacket)

					// Return the actual LUMA frame
					//
					// This is actually a YUV 4:4:2 frame, which starts with a full-frame of luminance image data

					// // Note: We create an ImageBuffer in which we own the buffer memory (i.e., faster and no copy)
					// return LumaBuffer(width: Int(codecCtx.width), height: Int(codecCtx.height), buffer: frame.data.0!)

					let buffer = LumaBuffer(width: Int(codecCtx.width), height: Int(codecCtx.height))
					buffer.copy(from: frame.data.0!, width: Int(codecCtx.width), height: Int(codecCtx.height))
					return buffer
				}
				else
				{
					mNonVideoFrameCount += 1
				}
			}
			catch
			{
				// Log the error
				gLogger.error("Caught VideoException: \(error.localizedDescription)")
			}

			// Free the packet that was allocated by av_read_frame
			av_packet_unref(&mPacket)
		}

		// No more frames (or an error), so uninitialize the video
		stop()

		// Nothing to return
		return nil
	}

	/// Stop and uninitialize video decoding
	///
	/// It is not necessary to call this method at the end of the video (received `nil` from `decodeFrame()`) as the decoder
	/// will already have been stopped.
	///
	/// Throws VideoException on error
	public func stop()
	{
		// Free the YUV frame
		if mpFrame != nil
		{
			av_frame_free(&mpFrame)
			mpFrame = nil
		}

		// Close the codecs
		if mpCodecCtx != nil
		{
			avcodec_close(mpCodecCtx)
			avcodec_free_context(&mpCodecCtx)
			mpCodecCtx = nil
		}

		// Close the video file
		if mpFormatCtx != nil
		{
			avformat_close_input(&mpFormatCtx)
			mpFormatCtx = nil
		}

		// Clean out the URL
		mVideoUrl = PathString()

		// We're no longer initialized
		if mVideoInitialized
		{
			// Final logging
			gLogger.video("Decoding uninitialized")
			gLogger.video("  >> Frames decoded  : \(mDecodedFrameCount)")
			gLogger.video("  >> Non-video frames: \(mNonVideoFrameCount)")
		}

		// We're no longer initialized
		mVideoInitialized = false
	}
}

#endif // os(macOS) || os(Linux)
