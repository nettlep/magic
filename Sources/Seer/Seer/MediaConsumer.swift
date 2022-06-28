//
//  MediaConsumer.swift
//  Seer
//
//  Created by Paul Nettle on 04/18/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
#if os(iOS)
import MinionIOS
#else
import Minion
#endif

/// Provides a common, generic functionality for receiving media, sending it through the scanning process, sharing results with
/// any connected peers and even providing debug output (stats and modified video frames) to a viewport.
public class MediaConsumer
{
	/// The ScanManager: The entry point into the scanning process
	public let scanManager = ScanManager()

	/// The object responsible for validating the scanned deck against the known test deck order
	public var resultValidator = ResultValidator()

	/// The message used to send scan reports over UDP
	private var udpScanReport = ScanReportMessage()

	/// The message used to send scan reports over UDP
	private var udpPerfReport = PerformanceStatsMessage()

	/// The viewport for displaying debug output
	private let mediaViewport: MediaViewportProvider?

	/// Time that a deck was last found in the image
	///
	/// If this value is set to 0, the respite time is reset
	private var lastFoundTimeMS: Time = 0

	/// Time that a frame was last scanned
	private var lastScanTimeMS: Time = 0

	/// Are we in battery saver mode?
	private var batterySaverActive: Bool = false
	{
		willSet
		{
			if batterySaverActive && !newValue
			{
				gLogger.search("BatterySaver: deactivated")
			}
			else if !batterySaverActive && newValue
			{
				gLogger.search("BatterySaver: activated")
			}
		}
	}

	/// Debug buffer callback
	///
	/// If registered, the caller will receive debug buffers each frame
	///
	/// Only one callback can be associated at a given time. Therefore, setting two callbacks would result in the first callback
	/// being overridden by the first and only one callback (the second) being called.
	public func setDebugFrameCallback(_ callback: @escaping (_ debugBuffer: DebugBuffer?) -> Void)
	{
		assert(debugFrameCallback == nil)
		debugFrameCallback = callback
	}
	private var debugFrameCallback: ((_ debugBuffer: DebugBuffer?) -> Void)?

	/// Luma buffer callback
	///
	/// If registered, the caller will receive luma buffers each frame
	///
	/// Only one callback can be associated at a given time. Therefore, setting two callbacks would result in the first callback
	/// being overridden by the first and only one callback (the second) being called.
	public func setLumaFrameCallback(_ callback: @escaping (_ lumaBuffer: LumaBuffer?) -> Void)
	{
		assert(lumaFrameCallback == nil)
		lumaFrameCallback = callback
	}
	private var lumaFrameCallback: ((_ lumaBuffer: LumaBuffer?) -> Void)?

	/// Server used to send results to any connected peers
	public private(set) var server: Server?

	/// The number of frames scanned thus far
	private var scanFrameCount = 0

	/// Our mutex for processing
	///
	/// Generally, this is used to allow other threads to know when it is safe to modify stuff (such as the CodeDefinition) so they
	/// do not try to do so while processing is happening
	private var ProcessingMutex = PThreadMutex()

	/// Returns `true` if the MediaConsumer has been started, otherwise `false`
	public var isStarted: Bool { return server != nil }

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	public init(mediaViewport: MediaViewportProvider?)
	{
		self.mediaViewport = mediaViewport
	}

	deinit
	{
		stop()
	}

	/// Starts the consumer
	public func start(loopback: Bool = false, peerFactory: Server.PeerFactory?)
	{
		if server != nil
		{
			return
		}

		// Start a server to share our data
		if let peerFactory = peerFactory
		{
			server = Server()
			if nil == server!.start(loopback: loopback, peerFactory: peerFactory)
			{
				gLogger.error("MediaConsumer: Failed to start the server")
			}
		}
		else
		{
			gLogger.error("MediaConsumer: Not creating a server (no peer factory provided)")
		}
	}

	/// Halts all processing of the media consumer and kills the running server, if one exists
	public func stop()
	{
		// Shut down our server
		server?.stop()
		server = nil
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Media/content updates
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Execute the given block when the `MediaConsumer` is not currently processing.
	///
	/// If processing is active, this method will block until it finishes.
	///
	/// Note that this method uses a Mutex and therefore can be subject to deadlocks.
	public func executeWhenNotProcessing<Result>(_ block: @escaping () -> Result) -> Result
	{
		return ProcessingMutex.fastsync
		{
			return block()
		}
	}

	/// Determin if scanning is appropriate
	///
	/// Scanning can be disabled by the battery saver. This works using two variables from the Config section,
	/// `searchBatterySaverStartMS` and `search.BatterySaverIntervalMS`.
	///
	/// If a deck is not found within the period of time specified by `searchBatterySaverStartMS`, the battery saver is
	/// initiated.
	///
	/// During battery saver scanning is performed for one frame every `searchBatterySaverIntervalMS` milliseconds until a deck
	/// is found, at which point battery saver is disabled again.
	public func shouldScan() -> Bool
	{
		// Our current time
		let currentTimeMS = PausableTime.getTimeMS()

		// If the deck found time was reset (or never set) then start it now and allow scanning
		if lastFoundTimeMS == 0
		{
			lastFoundTimeMS = currentTimeMS
			batterySaverActive = false
			return true
		}

		// How much time has elapsed since we've last seen a deck?
		let deltaFoundTimeMS = Int(currentTimeMS - lastFoundTimeMS)

		// If not enough time has elapsed for battery saver, allow scanning
		if deltaFoundTimeMS < Config.searchBatterySaverStartMS
		{
			batterySaverActive = false
			return true
		}

		// We're in battery saver mode
		batterySaverActive = true

		// How much time has elapsed since we've last scanned a deck?
		let deltaScanTimeMS = Int(currentTimeMS - lastScanTimeMS)

		// If not enough battery saver time has elapsed for a scan, don't allow scanning
		if deltaScanTimeMS < Config.searchBatterySaverIntervalMS
		{
			// Update our stats so we can track it
			// TextUi.instance.clearPerf()
			// TextUi.instance.perfLine(line: 0, text: "Battery saver active - Time since last scan: \(deltaScanTimeMS)ms")

			return false
		}

		// Allow a single scan in battery saver mode
		// gLogger.search("BatterySaver: Performing periodic scan")
		return true
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Formal implementation - processing frames of data
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Process a single frame of data
	///
	/// This is the full processor, responsible for performing the actual scanning as well as any pre/postprocessing, sending
	/// results to peers, updating stats and the viewport, etc.
	public func processFrame(lumaBuffer: LumaBuffer, codeDefinition: CodeDefinition)
	{
		scanFrameCount += 1

		let debugBuffer = debugPreprocess(lumaBuffer: lumaBuffer)

		// Scan this image and attempt to read the deck
		let analysisResult = scanManager.scan(debugBuffer: debugBuffer, lumaBuffer: lumaBuffer, codeDefinition: codeDefinition)

		// Update our last scan time
		lastScanTimeMS = PausableTime.getTimeMS()

		// Track our debug times
		let debugStart = PerfTimer.trackBegin()

		// Did we find a deck?
		if analysisResult.deckSearchResult.isFound
		{
			// We found a deck, update our timer to track when the deck was last found
			lastFoundTimeMS = PausableTime.getTimeMS()
		}

		if let server = server
		{
			if Config.debugViewportDebugView && debugBuffer != nil
			{
				sendViewport(server: server, debugBuffer: debugBuffer!)
				debugFrameCallback?(debugBuffer)
			}
			else
			{
				sendViewport(server: server, lumaBuffer: lumaBuffer)
				lumaFrameCallback?(lumaBuffer)
			}
			sendResults(server: server, analysisResult: analysisResult)
		}

		if Config.debugValidateResults
		{
			_ = resultValidator.validateResults(debugBuffer: debugBuffer, codeDefinition: codeDefinition, stats: &scanManager.resultStats, analysisResult: analysisResult)
		}

		// Update our diagnostic stats
		mediaViewport?.updateStats(analysisResult: analysisResult, stats: scanManager.resultStats)

		PerfTimer.trackEnd(name: "Debug", start: debugStart)

		// Next frame
		PerfTimer.nextFrame()

		debugPostprocess(debugBuffer: debugBuffer)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Call this method to fully reset cumulative stats output
	public func resetStats()
	{
		scanManager.reset()
	}

	/// Perform any debug preprocessing prior to scanning
	///
	/// This includes image processing functions and generating a debug buffer for viewport analysis
	private func debugPreprocess(lumaBuffer: LumaBuffer) -> DebugBuffer?
	{
		let debugStart = PerfTimer.trackBegin()

		// Image preprocessing adjustments for the Luma buffer
		lumaBuffer.preprocess()

		// Copy it to our debugBuffer
		var debugBuffer: DebugBuffer?
		if Config.testbedDrawViewport || Config.debugViewportDebugView
		{
			debugBuffer = DebugBuffer(width: lumaBuffer.width, height: lumaBuffer.height)
			do
			{
				try debugBuffer!.copy(from: lumaBuffer)
			}
			catch
			{
				gLogger.error("Failed to copy the frame buffer to the front window: \(error.localizedDescription)")
			}
		}

		// Image preprocessing adjustments for the Color buffer
		debugBuffer?.preprocess(lumaBuffer: lumaBuffer)

		PerfTimer.trackEnd(name: "Debug", start: debugStart)
		return debugBuffer
	}

	/// Perform any debug postprocessing after scanning
	///
	/// This includes updating the debug viewport with the current debug image
	private func debugPostprocess(debugBuffer: DebugBuffer?)
	{
		let debugStart = PerfTimer.trackBegin()

		mediaViewport?.updateLocalViewport(debugBuffer: debugBuffer)

		PerfTimer.trackEnd(name: "Debug", start: debugStart)
	}

	/// Sends the Luma viewport to all connected peers
	///
	/// This operation only happens every `Config.captureViewportFrequencyFrames` frames
	private func sendViewport(server: Server, lumaBuffer: LumaBuffer)
	{
		if scanFrameCount % Config.captureViewportFrequencyFrames != 0 { return }

		let viewportStart = PerfTimer.trackBegin()

		var maxDim = 0
		var minDim = 0
		var width = 0
		var height = 0
		if lumaBuffer.width > lumaBuffer.height
		{
			minDim = lumaBuffer.height
			maxDim = lumaBuffer.width
			let ratio = Float(minDim) / Float(maxDim)
			height = Int(sqrt(Float(minDim) / Float(maxDim) * Float(Packet.kMaxPacketSizeBytes)))
			width = Int(Float(height) / ratio)
		}
		else
		{
			minDim = lumaBuffer.width
			maxDim = lumaBuffer.height
			let ratio = Float(minDim) / Float(maxDim)
			width = Int(sqrt(Float(minDim) / Float(maxDim) * Float(Packet.kMaxPacketSizeBytes)))
			height = Int(Float(width) / ratio)
		}

		let newImage = LumaBuffer(width: width, height: height)

		let viewportType = ViewportMessage.ViewportType.fromUInt8(UInt8(Config.captureViewportType.rawValue))
		switch viewportType
		{
			case .LumaResampledToViewportSize:
				newImage.resampleLerpFast(from: lumaBuffer)

			case .LumaCenterViewportRect:
				let sx0 = max((lumaBuffer.width - width) / 2, 0)
				let sy0 = max((lumaBuffer.height - height) / 2, 0)

				let sx1 = min(sx0 + width, lumaBuffer.width)
				let sy1 = min(sy0 + height, lumaBuffer.height)

				var dy = 0
				for sy in sy0..<sy1
				{
					let src = lumaBuffer.buffer + sy * lumaBuffer.width
					let dst = newImage.buffer + dy * width
					dy  += 1

					var dx = 0
					for sx in sx0..<sx1
					{
						dst[dx] = src[sx]
						dx += 1
					}
				}
		}

		if let buffer = newImage.buffer.toData(count: width * height)
		{
			if let payload = ViewportMessage(viewportType: viewportType, width: UInt16(width), height: UInt16(height), buffer: buffer).getPayload()
			{
				server.send(payload: payload)
			}
			else
			{
				gLogger.error("MediaConsumer.sendViewport: Failed to send Viewport message")
			}
		}
		else
		{
			gLogger.error("MediaConsumer.sendViewport: Failed to generate image data for Viewport message")
		}

		PerfTimer.trackEnd(name: "Viewport", start: viewportStart)
	}

	/// Sends the Debug viewport to all connected peers
	///
	/// This operation only happens every `Config.captureViewportFrequencyFrames` frames
	private func sendViewport(server: Server, debugBuffer: DebugBuffer)
	{
		let lumaBuffer = LumaBuffer(width: debugBuffer.width, height: debugBuffer.height)

		do
		{
			try lumaBuffer.copy(from: debugBuffer.buffer, width: debugBuffer.width, height: debugBuffer.height)
			sendViewport(server: server, lumaBuffer: lumaBuffer)
		}
		catch
		{
			gLogger.error("MediaConsumer.sendViewport: Failed to convert debug to luma image")
		}
	}

	/// Sends scan analysis results to all connected peers
	private func sendResults(server: Server, analysisResult: AnalysisResult)
	{
		if let payload = ScanMetadataMessage(frameCount: UInt32(scanFrameCount), status: analysisResult.parsableDescription).getPayload()
		{
			server.send(payload: payload)
		}
		else
		{
			gLogger.error("FrameView.updateImage: Failed to generate ScanMetadata message")
		}

		if let deck = analysisResult.deck
		{
			if analysisResult.isSuccessHighConfidence || (analysisResult.isSuccessLowConfidence && Config.analysisEnableLowConfidenceReports)
			{
				let highConfidence = analysisResult.isSuccessHighConfidence
				let confidence = analysisResult.confidenceFactor ?? 0
				let indices = deck.resolvedIndices
				let resolvedRobustness = deck.resolvedRobustness

				// Send the report over UDP
				udpScanReport.update(highConfidence: highConfidence, formatId: deck.format.id, confidenceFactor: UInt8(confidence), indices: indices, robustness: resolvedRobustness)

				if let payload = udpScanReport.getPayload()
				{
					server.send(payload: payload)
				}
				else
				{
					gLogger.error("Scanner.onResultSuccess: Failed to generate ScanReport message")
				}
			}
		}

		// Send our performance stats
		udpPerfReport.update()
		if let payload = udpPerfReport.getPayload()
		{
			server.send(payload: payload)
		}
	}
}
