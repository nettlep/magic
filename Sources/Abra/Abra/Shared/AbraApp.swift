//
//  abraApp.swift
//  Abra
//
//  Created by Paul Nettle on 9/13/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI
#if os(iOS)
import UIKit
import SeerIOS
import MinionIOS
import NativeTasksIOS
#else
import Seer
import Minion
import NativeTasks
#endif

#if os(macOS)
import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		return true
	}
}
#endif

@main
class AbraApp: App {
	#if os(macOS)
	// swiftlint:disable weak_delegate
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	#endif

	// -----------------------------------------------------------------------------------------------------------------------------
	// Provide a singleton-like interface
	// -----------------------------------------------------------------------------------------------------------------------------

	private static var _shared: AbraApp?
	internal static var shared: AbraApp
	{
		assert(_shared != nil)
		return _shared!
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Constants
	// -----------------------------------------------------------------------------------------------------------------------------

	private static let kConfigFileBaseName = "whisper.conf"
	private static let kGrayColorSpace = CGColorSpaceCreateDeviceGray()
	private static let kColorColorSpace = CGColorSpaceCreateDeviceRGB()
	private static let kRunningStatsCount = 30 * 5

	internal static let kButtonSize: CGFloat = 38
	internal static let kButtonLineWidth: CGFloat = 3

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	public private(set) var clientPeer: AbraClientPeer?
	private var mediaConsumer: MediaConsumer?
	private var firstFrame = true
	private var lastConfidenceFactor: UInt8 = 0
	private var runningFrameToFrameTimeMS: [Real] = []
	private var runningFullFrameMS: [Real] = []
	private var runningScanMS: [Real] = []

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	required init()
	{
		AbraApp._shared = self

		// Load our code definitions first
		CodeDefinition.loadCodeDefinitions(fastLoad: true)

		// Initialize our configuration
		Config.loadConfiguration(configBaseName: AbraApp.kConfigFileBaseName)

		// Initialize the logger
		initLogging()

		// Setup a log notification for code definition changes
		_=Config.addValueChangeNotificationReceiver
		{
			guard let name = $0 else { return }
			if name == "search.CodeDefinition"
			{
				if let newValue = Config.configDict[name]?["value"] as? String
				{
					if newValue != Preferences.shared.deckFormatName
					{
						gLogger.info("Code definition changed to \(newValue)")
					}
				}
				else
				{
					gLogger.info("Code definition removed")
				}
			}
		}

		// Ensure the deckFormatName in our preferences is valid
		if let formatName = Preferences.shared.deckFormatName
		{
			// If that name doesn't exist, clear it out
			if CodeDefinition.findCodeDefinition(byName: formatName) == nil
			{
				Preferences.shared.deckFormatName = nil
			}
		}

		// If we don't have one, try to set a default
		if Preferences.shared.deckFormatName == nil
		{
			Preferences.shared.deckFormatName = CodeDefinition.codeDefinitions.first?.format.name
		}

		// Sync the code definition through preferences and the UI
		ServerConfig.shared.setCodeDefinition(withName: Preferences.shared.deckFormatName)

		// Disable SIGPIPE, which helps when we get a pipe error for the client/server
		signal(SIGPIPE, SIG_IGN)

		UIState.shared.localServerEnabled = Preferences.shared.localServerEnabled
		UIState.shared.advertiseServer = Preferences.shared.advertiseServer

		// We don't want to start a server if we're in preview mode
		if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
		{
			UIState.shared.serverAddress = Ipv4SocketAddress(address: 123, port: 456)
			return
		}

		onServerTypeUpdated()

		startClient()
	}

	/// Initialize the logging subsystem
	///
	/// This method will initialize logging with the appropriate logging mechanisms. That is:
	///
	///     - A file-based log
	///     - A text-based user interface log (if the text-based user interface is enabled)
	///     - A console log (if the text-based user interface is NOT enabled)
	private func initLogging()
	{
		gLogger.trace("Initializing logger")

		// Defaults in the config file at the time of writing Abra
		//Config.logMasks["UI"] = "!all !debug  info  warn  error  severe  fatal !trace !perf !status !frame !search !decode !resolve !badresolve !correct !incorrect !result !badreport !network"
		//Config.logMasks["Console"] = "!all !debug  info  warn  error  severe  fatal !trace !perf !status !frame !search !decode !resolve !badresolve !correct !incorrect !result !badreport !network"
		//Config.logMasks["File"] = "!all !debug  info  warn  error  severe  fatal !trace !perf !status !frame !search !decode !resolve !badresolve !correct !incorrect !result !badreport !network"

		// Adding flags for various debug purposes
		//Config.logMasks["UI"]! += " network"
		//Config.logMasks["Console"]! += " network"

		// Setup the logger
		if !gLogger.registerDevice(device: LogDeviceConsole(), logMasks: Config.logMasks)
		{
			gLogger.error("Unable to register console logging device")
		}

		if !gLogger.registerDevice(device: AbraLogDevice(), logMasks: Config.logMasks)
		{
			gLogger.error("Unable to register view logging device")
		}

		// Register the loggers with the native interface
		typealias LogOutputCapture = @convention(c) (UnsafePointer<CChar>) -> Void
		nativeLogRegisterDebug(unsafeBitCast( { gLogger.debug(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterInfo(unsafeBitCast( { gLogger.info(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterWarn(unsafeBitCast( { gLogger.warn(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterError(unsafeBitCast( { gLogger.error(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterSevere(unsafeBitCast( { gLogger.severe(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterFatal(unsafeBitCast( { gLogger.fatal(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterTrace(unsafeBitCast( { gLogger.trace(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterPerf(unsafeBitCast( { gLogger.perf(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterStatus(unsafeBitCast( { gLogger.status(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterFrame(unsafeBitCast( { gLogger.frame(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterSearch(unsafeBitCast( { gLogger.search(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterDecode(unsafeBitCast( { gLogger.decode(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterResolve(unsafeBitCast( { gLogger.resolve(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterBadResolve(unsafeBitCast( { gLogger.badResolve(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterCorrect(unsafeBitCast( { gLogger.correct(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterIncorrect(unsafeBitCast( { gLogger.incorrect(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterResult(unsafeBitCast( { gLogger.result(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterBadReport(unsafeBitCast( { gLogger.badReport(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterNetwork(unsafeBitCast( { gLogger.network(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterNetworkData(unsafeBitCast( { gLogger.networkData(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterVideo(unsafeBitCast( { gLogger.video(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))
		nativeLogRegisterAlways(unsafeBitCast( { gLogger.always(String(cString: $0)) } as LogOutputCapture, to: NativeLogReceiver.self))

		// Start the logger
		gLogger.start(broadcastMessage: ">>> Session starting")
		gLogger.always(">>> VCS revisions:")
		gLogger.always(">>>    Abra:    \(AbraVersion)")
		gLogger.always(">>>    Seer:    \(SeerVersion)")
		gLogger.always(">>>    Minion:  \(MinionVersion)")
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Client/server management
	// -----------------------------------------------------------------------------------------------------------------------------

	func onServerTypeUpdated()
	{
		DispatchQueue.global().async
		{
			_ = self.clientPeer?.hangup()
			_ = self.clientPeer?.start()
		}

		if Preferences.shared.localServerEnabled
		{
			setDisconnected()
			startLocalServer()
		}
		else
		{
			stopLocalServer()
		}
	}

	func startLocalServer()
	{
		DispatchQueue.global().async
		{
			self.mediaConsumer?.stop()

			if self.mediaConsumer == nil
			{
				self.mediaConsumer = MediaConsumer(mediaViewport: nil)
				self.mediaConsumer?.setDebugFrameCallback(self.onLocalServerDebugFrame)
				self.mediaConsumer?.setLumaFrameCallback(self.onLocalServerLumaFrame)
			}

			if let mediaConsumer = self.mediaConsumer
			{
				mediaConsumer.start(loopback: Preferences.shared.isLocalLoopback, peerFactory: AbraServerPeer.createAbraServerPeer)
				AbraCaptureMediaProvider.shared.start(mediaConsumer: mediaConsumer)
			}
		}
	}

	func stopLocalServer()
	{
		DispatchQueue.global().async
		{
			if self.mediaConsumer != nil
			{
				AbraCaptureMediaProvider.shared.stop()
				self.mediaConsumer?.stop()
				self.mediaConsumer = nil
			}
		}
	}

	func startClient()
	{
		DispatchQueue.global().async
		{
			self.clientPeer = AbraClientPeer(client: self)
			if nil == self.clientPeer
			{
				gLogger.error("AbraApp.startClient: Failed to initialize client")
			}
			else
			{
				gLogger.network("AbraApp.startClient: Starting client advertiser")
				if !self.clientPeer!.start()
				{
					gLogger.error("AbraApp.startClient: Failed to start the client advertiser")
				}
			}
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// View implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	var body: some Scene {
		WindowGroup {
			MenuView()
#if os(macOS)
			.frame(minWidth: 600, idealWidth: 1000, maxWidth: .infinity, minHeight: 600, idealHeight: 1000, maxHeight: .infinity, alignment: .center)
#endif
			.environmentObject(UIState.shared)
			.environmentObject(ServerConfig.shared)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Connection status
	// -----------------------------------------------------------------------------------------------------------------------------

	public func setConnected(versions: [String: String]? = nil)
	{
		DispatchQueue.main.async
		{
			UIState.shared.serverVersions = versions
			UIState.shared.serverAddress = self.clientPeer?.socketAddress
		}
	}

	public func setDisconnected(reason: String? = nil)
	{
		DispatchQueue.main.async
		{
			UIState.shared.serverVersions = [String: String]()
			UIState.shared.serverAddress = nil
			UIState.shared.viewportImage = nil
		}

		ServerConfig.shared.populate([])
	}

	public func allowConnection(from socketAddress: Ipv4SocketAddress) -> Bool
	{
		// We only limit connections in local server mode
		if !Preferences.shared.localServerEnabled { return true }

		return mediaConsumer?.server?.serverPeer?.socketAddress == socketAddress
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Viewport
	// -----------------------------------------------------------------------------------------------------------------------------

	func onLocalServerDebugFrame(_ image: DebugBuffer?)
	{
		// If we're not playing, don't process this report
		if UIState.shared.paused { return }

		guard let image = image else { return }

		let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

		DispatchQueue.main.async
		{
			if let providerRef = CGDataProvider(data: NSData(bytes: image.buffer, length: image.width * image.height * 4))
			{
				if let cgim = CGImage(
					width: image.width,
					height: image.height,
					bitsPerComponent: 8,
					bitsPerPixel: 32,
					bytesPerRow: image.width * 4,
					space: AbraApp.kColorColorSpace,
					bitmapInfo: bitmapInfo,
					provider: providerRef,
					decode: nil,
					shouldInterpolate: false,
					intent: CGColorRenderingIntent.defaultIntent)
				{
					#if os(iOS)
					UIState.shared.viewportImage = Image(uiImage: UIImage(cgImage: cgim))
					#else
					UIState.shared.viewportImage = Image(nsImage: NSImage(cgImage: cgim, size: NSSize(width: image.width, height: image.height)))
					#endif
				}
			}
		}
	}

	func onLocalServerLumaFrame(_ image: LumaBuffer?)
	{
		// If we're not playing, don't process this report
		if UIState.shared.paused { return }

		guard let image = image else { return }

		let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

		DispatchQueue.main.async
		{
			if let providerRef = CGDataProvider(data: NSData(bytes: image.buffer, length: image.width * image.height))
			{
				if let cgim = CGImage(
					width: image.width,
					height: image.height,
					bitsPerComponent: 8,
					bitsPerPixel: 8,
					bytesPerRow: image.width,
					space: AbraApp.kGrayColorSpace,
					bitmapInfo: bitmapInfo,
					provider: providerRef,
					decode: nil,
					shouldInterpolate: false,
					intent: CGColorRenderingIntent.defaultIntent)
				{
					#if os(iOS)
					UIState.shared.viewportImage = Image(uiImage: UIImage(cgImage: cgim))
					#else
					UIState.shared.viewportImage = Image(nsImage: NSImage(cgImage: cgim, size: NSSize(width: image.width, height: image.height)))
					#endif
				}
			}
		}
	}

	func processViewport(_ message: ViewportMessage)
	{
		// We'll either get a Debug or a Luma buffer in a local server setup
		if Preferences.shared.localServerEnabled { return }

		// If we're not playing, don't process this report
		if UIState.shared.paused { return }

		let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

		let width = Int(message.width)
		let height = Int(message.height)
		var data = message.buffer.toArray(type: UInt8.self)
		assert(data.count == width * height)

		DispatchQueue.main.async
		{
			if let providerRef = CGDataProvider(data: NSData(bytes: &data, length: data.count))
			{
				if let cgim = CGImage(
					width: width,
					height: height,
					bitsPerComponent: 8,
					bitsPerPixel: 8,
					bytesPerRow: width,
					space: AbraApp.kGrayColorSpace,
					bitmapInfo: bitmapInfo,
					provider: providerRef,
					decode: nil,
					shouldInterpolate: false,
					intent: CGColorRenderingIntent.defaultIntent)
				{
					#if os(iOS)
					UIState.shared.viewportImage = Image(uiImage: UIImage(cgImage: cgim))
					#else
					UIState.shared.viewportImage = Image(nsImage: NSImage(cgImage: cgim, size: NSSize(width: width, height: height)))
					#endif
				}
			}
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Actions
	// -----------------------------------------------------------------------------------------------------------------------------

	func onSendVibration()
	{
		DispatchQueue.global().async
		{
			if !(self.clientPeer?.send(TriggerVibrationMessage()) ?? false)
			{
				gLogger.error("AbraApp.onSendVibration: Failed to send vibration feedback")
				return
			}
		}
	}

	func onShutdown()
	{
		DispatchQueue.global().async
		{
			if !(self.clientPeer?.send(CommandMessage(command: CommandMessage.kShutdown, parameters: [String]())) ?? false)
			{
				gLogger.error("AbraApp.onShutdown: Unable to send shutdown command")
			}
		}
	}

	func onReboot()
	{
		DispatchQueue.global().async
		{
			if !(self.clientPeer?.send(CommandMessage(command: CommandMessage.kReboot, parameters: [String]())) ?? false)
			{
				gLogger.error("AbraApp.onReboot: Unable to send reboot command")
			}
		}
	}

	func onCheckForUpdates()
	{
		DispatchQueue.global().async
		{
			if !(self.clientPeer?.send(CommandMessage(command: CommandMessage.kCheckForUpdates, parameters: [String]())) ?? false)
			{
				gLogger.error("AbraApp.OnCheckForUpdates: Unable to send check-for-updates command")
			}
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Reporting
	// -----------------------------------------------------------------------------------------------------------------------------

	func processReport(_ data: Data)
	{
		var consumed: Int = 0
		if let report = ScanReportMessage.decode(from: data, consumed: &consumed)
		{
			processReport(report)
		}
	}

	func processReport(_ message: ScanReportMessage)
	{
		var missingString = ""

		if message.indices.count == 0 { return }

		var presentIndices = [UInt8]()
		var presentCards = [Card]()
		var missingCards = [Card]()

		guard let codeDefinition = CodeDefinition.findCodeDefinition(byId: Int(message.formatId)) else
		{
			gLogger.error("Unable to find code definition for ID: \(message.formatId)")
			return
		}

		let deckFaceCodesMap = codeDefinition.format.faceCodesNdo

		for i in 0..<message.indices.count
		{
			let index = message.indices[i]
			let robustness = message.robustness.count > i ? message.robustness[i] : 0

			let cardIndex = Int(index)
			presentIndices.append(index)

			if cardIndex < codeDefinition.format.maxCardCountWithReversed
			{
				let faceCode = deckFaceCodesMap[cardIndex]
				if let card = Card(faceCode: faceCode, state: robustness == 0 ? [.fragile]:[])
				{
					presentCards.append(card)
				}
				else
				{
					gLogger.error("Unable to create present card for face code: \(faceCode)")
				}
			}
			else
			{
				gLogger.error("Card index out of range: \(cardIndex)")
			}
		}

		for i in 0..<codeDefinition.format.maxCardCount
		{
			// A card is only missing if it's index and reversed index is not present
			if presentIndices.firstIndex(of: UInt8(i)) == nil && presentIndices.firstIndex(of: UInt8(i+codeDefinition.format.maxCardCount)) == nil
			{
				if !missingString.isEmpty
				{
					missingString += " "
				}

				let faceCode = deckFaceCodesMap[i]
				missingString += faceCode

				if let card = Card(faceCode: faceCode, state: [.missing])
				{
					missingCards.append(card)
				}
				else
				{
					gLogger.error("Unable to create missing card for face code: \(faceCode)")
				}
			}
		}

		let cardsRequired = codeDefinition.format.maxCardCount

		// Proper number of cards?
		let fullDeck = cardsRequired == presentIndices.count

		// Don't process this report any further
		if UIState.shared.paused
		{
			// Exception: If we still have a full deck and a better confidence factor, we'll take it
			let improvedConfidence = message.confidenceFactor > lastConfidenceFactor
			if !firstFrame && (!improvedConfidence || !fullDeck) { return }
			firstFrame = false
		}

		// Track our most recent confidence factor
		self.lastConfidenceFactor = message.confidenceFactor

		DispatchQueue.main.async
		{
			// Check the order of the indices
			var ndo = fullDeck
			if ndo
			{
				let scannedOrder = codeDefinition.format.getFaceCodes(indices: presentIndices)
				for i in 0..<presentIndices.count
				{
					if codeDefinition.format.faceCodesTestDeckOrder[i] != scannedOrder[i]
					{
						ndo = false
						break
					}
				}
			}

			UIState.shared.ndo = ndo

			UIState.shared.cardCount = presentCards.count

			UIState.shared.confidencePercent = Int(message.confidenceFactor)

			UIState.shared.cards = presentCards
			UIState.shared.cards.append(contentsOf: missingCards)

			// If we have exactly a full deck, auto-pause (note that we do this after updating everything)
			if fullDeck && UIState.shared.autoPauseEnabled
			{
				UIState.shared.paused = true
			}
		}
	}

	public func createCard(format: DeckFormat, faceCode: String, robustness: UInt8 = 0) -> Card?
	{
		return Card(faceCode: faceCode, state: robustness == 0 ? [.fragile]:[])
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Metadata
	// -----------------------------------------------------------------------------------------------------------------------------

	enum MetadataStatus
	{
		case NotSharp
		case TooSmall
		case NotFound
		case TooFew
		case Inconclusive
		case NotEnoughHistory
		case NotEnoughConfidence
		case ResultLowConfidence
		case ResultHighConfidence
		case GeneralFailure

		init(_ value: String)
		{
			switch value
			{
				// Instructional
				case "NS": self = .NotSharp
				case "TS": self = .TooSmall
				case "NF": self = .NotFound
				case "TF": self = .TooFew

				// Resultant
				case "NC": self = .NotEnoughConfidence
				case "RL": self = .ResultLowConfidence
				case "RH": self = .ResultHighConfidence

				// Other
				case "IN": self = .Inconclusive
				case "NH": self = .NotEnoughHistory
				default: self = .GeneralFailure
			}
		}

		var isInstructional: Bool
		{
			switch self
			{
				case .NotSharp, .TooSmall, .NotFound, .TooFew: return true
				default: return false
			}
		}

		var isResultant: Bool
		{
			switch self
			{
				case .NotEnoughConfidence, .ResultLowConfidence, .ResultHighConfidence: return true
				default: return false
			}
		}

		var isOther: Bool
		{
			switch self
			{
				case .Inconclusive, .NotEnoughHistory, .GeneralFailure: return true
				default: return false
			}
		}
	}

	func processPerformanceStats(_ message: PerformanceStatsMessage)
	{
		// If we're not playing, don't process this report
		if UIState.shared.paused { return }

		if runningFrameToFrameTimeMS.count >= AbraApp.kRunningStatsCount { runningFrameToFrameTimeMS.removeFirst() }
		runningFrameToFrameTimeMS.append(message.frameToFrameTimeMS)

		if runningFullFrameMS.count >= AbraApp.kRunningStatsCount { runningFullFrameMS.removeFirst() }
		runningFullFrameMS.append(message.fullFrameMS)

		if runningScanMS.count >= AbraApp.kRunningStatsCount { runningScanMS.removeFirst() }
		runningScanMS.append(message.scanMS)

		// Calc recent averages
		var frameToFrameTimeMS: Real = 0
		for value in runningFrameToFrameTimeMS { frameToFrameTimeMS += value }
		if runningFrameToFrameTimeMS.count > 0 { frameToFrameTimeMS /= Real(runningFrameToFrameTimeMS.count) }

		var fullFrameMS: Real = 0
		for value in runningFullFrameMS { fullFrameMS += value }
		if runningFullFrameMS.count > 0 { fullFrameMS /= Real(runningFullFrameMS.count) }

		var scanMS: Real = 0
		for value in runningScanMS { scanMS += value }
		if runningScanMS.count > 0 { scanMS /= Real(runningScanMS.count) }

		DispatchQueue.main.async
		{
			UIState.shared.perfFps = frameToFrameTimeMS > 0 ? "\((1000 / frameToFrameTimeMS).roundToNearest())" : "0"
			UIState.shared.perfFullFrameMs = String(format: "%0.1f", fullFrameMS)
			UIState.shared.perfScanMs = String(format: "%0.1f", scanMS)
		}
	}

	func processMetadata(_ message: ScanMetadataMessage)
	{
		// If we're not playing, don't process this report
		if UIState.shared.paused { return }

		DispatchQueue.main.async
		{
			var instructionalStatus: MetadataStatus?
			var resultantStatus: MetadataStatus?
			var otherStatus: MetadataStatus?

			let mdStatus = MetadataStatus(message.status)
			if mdStatus.isInstructional
			{
				instructionalStatus = mdStatus
			}
			else if mdStatus.isResultant
			{
				resultantStatus = mdStatus
			}
			else
			{
				otherStatus = mdStatus
			}

			var resultText = ""

			if let instructionalStatus = instructionalStatus
			{
				switch instructionalStatus
				{
					case .NotSharp: resultText = "Not sharp"
					case .TooSmall: resultText = "Get closer"
					case .NotFound: resultText = "Not found"
					case .TooFew:   resultText = "Found, can't decode"
					default: break
				}
			}

			if let resultantStatus = resultantStatus
			{
				switch resultantStatus
				{
					case .NotEnoughConfidence:  resultText = "No confidence"
					case .ResultLowConfidence:  resultText = "Low confidence"
					case .ResultHighConfidence: resultText = "High confidence"
					default: break
				}
			}

			if let otherStatus = otherStatus
			{
				switch otherStatus
				{
					case .Inconclusive: 	resultText = "Inconclusive"
					case .NotEnoughHistory: resultText = "Waiting for confidence"
					case .GeneralFailure:   resultText = "Unable to decode"
					default: break
				}
			}

			UIState.shared.feedback = resultText
		}
	}
}
