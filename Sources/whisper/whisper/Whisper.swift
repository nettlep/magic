//
//  Whisper.swift
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
import NativeTasks

// ---------------------------------------------------------------------------------------------------------------------------------
// Globals
// ---------------------------------------------------------------------------------------------------------------------------------

internal class Whisper
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Constants
	// -----------------------------------------------------------------------------------------------------------------------------

	internal let kConfigFileBaseName = "whisper.conf"

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Global crashed flag to prevent reentry into the crash handler
	private var crashedFlag = false

	/// Singleton interface
	private static var singletonInstance: Whisper?
	static var instance: Whisper
	{
		get
		{
			if singletonInstance == nil
			{
				singletonInstance = Whisper()
			}

			return singletonInstance!
		}
		set
		{
			assert(singletonInstance != nil)
		}
	}

	/// Our media provider - either a `WhisperVideoMediaProvider` or `WhisperCaptureMediaProvider`
	internal var mediaProvider: MediaProvider?

	/// Our media consumer
	internal var mediaConsumer: MediaConsumer?

	/// Our media viewport provider
	internal var viewportProvider: WhisperMediaViewportProvider?

	/// Our command line parser (with options storage)
	internal var commandLine = CommandLineParser()

	/// If true, the application will quit at the earliest possible time
	internal var shutdownRequested = AtomicFlag()

	/// Paused flag
	internal var isPaused = AtomicFlag()

	/// Should we restart playback on the next video frame
	internal var restartPlayback = AtomicFlag()

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	private init()
	{
	}

	/// Main Whisper application entry point
	internal func run()
	{
		// -------------------------------------------------------------------------------------------------------------------------
		// $CopyProtection$
		//
		// IMPORTANT!
		//
		// The order of initialization is important for copy protection reasons. Specifically:
		//
		// 1. On the 5th logger call (note the method starts with 6 'always' logs), the logger will have populated a concatenated
		//    string with the permanent device addresses (MAC addresses). Note that these will not reflect changes at the OS level
		//    for spoofing the MAC address.
		//
		// 2. We then use `TextUi` to collect the terminfo file data, which should hopefully hide it well. This file data is the
		//    pre-configured hash of secret plus the original hardware MAC addresses.
		//
		// 3. Similarly, we also use `TextUi` to provide us with the raw secret so we can generate a challenge hash.
		//
		// 4. We then use the `Sha256.sanityCheck` method to generate the hash containing the secret and devices. It also calculates
		//    the difference between the terminfo hash file's contents and the freshly generated hash. This difference is stored
		//    as a byte array of the differences. That array is returned returned as a binary hash.
		//
		// 5. This delta-hash is then stored in the `HammingDistance.errorCorrectionMap`, which is used to mess up the error
		//    correction maps, preventing valid decoding if the hashes are not equal. Specifically, correct hashes from the previous
		//    step would result in an array of zero-bytes. These values are then added/multiplied into the error correction data in
		//    such a way that zeros will not affect the final calculations, but any non-zero bytes will corrupt the tables.
		//
		// 6. Finally, when running, the decoding process will fail if the error correction tables were corrupted. The program will
		//    otherwise run perfectly fine.
		// -------------------------------------------------------------------------------------------------------------------------

		gLogger.always(">>> ----------------------------------------------------------------------------------------------------")
		gLogger.always(">>> - Whisper, Seer, Minion and NativeTasks are Copyright 2022 Paul Nettle. All Rights are reserved.   -")
		gLogger.always(">>> ----------------------------------------------------------------------------------------------------")
		gLogger.always(">>> Whisper: \(whisperVersion)")
		gLogger.always(">>> Seer:    \(SeerVersion)")
		gLogger.always(">>> Minion:  \(MinionVersion)")

		// Load our code definitions
		CodeDefinition.loadCodeDefinitions()

		// Initialize our configuration
		Config.loadConfiguration(configBaseName: kConfigFileBaseName)

		gLogger.info("Code definition initialized to \(Config.searchCodeDefinition?.format.name ?? "[none]")")

		// Setup a log notification for code definition changes
		_=Config.addValueChangeNotificationReceiver
		{
			guard let name = $0 else { return }
			if name == "search.CodeDefinition"
			{
				if let newValue = Config.configDict[name]?["value"]
				{
					gLogger.info("Code definition changed to \(newValue)")
				}
				else
				{
					gLogger.info("Code definition removed")
				}
			}
		}

		// Process our command line parameters, which may optionally modify our configuration
		if !commandLine.parseArguments() { return }

		// Initialize Whisper
		if !initialize()
		{
			gLogger.error("Whisper initialization failed, terminating now")
			viewportProvider?.uninit()
			return
		}

		mediaConsumer = MediaConsumer(mediaViewport: viewportProvider)
		mediaConsumer?.start(peerFactory: WhisperServerPeer.createWhisperServerPeer)

		// Now that we have our code definitions, set the one configured on the command line
		if let codeDefinition = commandLine.searchCodeDefinitionName
		{
			Config.searchCodeDefinition = CodeDefinition.findCodeDefinition(byName: codeDefinition)
		}

		if !commandLine.mediaFileUrls.isEmpty
		{
			mediaProvider = WhisperVideoMediaProvider.instance
		}
		else
		{
			#if USE_MMAL
			mediaProvider = WhisperCaptureMediaProvider.instance
			#endif
		}

		if mediaProvider == nil
		{
			gLogger.error("Whisper initialization failed - no media provider")
			viewportProvider?.uninit()
			return
		}

		mediaProvider?.start(mediaConsumer: Whisper.instance.mediaConsumer!)

		// Wait for completion
		mediaProvider?.waitUntilStopped()

		uninit()
	}

	// -----------------------------------------------------------------------------------------------------------------------------

	/// Begins the shutdown process
	///
	/// Calling this method will cause Whisper to eventually terminate
	///
	/// General shutdown method, which sets the `shouldQuit` flag and logs the caller-provided reason for the shutdown
	internal func shutdown(because reason: String)
	{
		gLogger.info("Whisper is shutting down (reason: \(reason))")
		shutdownRequested.value = true
	}

	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize all subsystems needed for Whisper to function
	private func initialize() -> Bool
	{
		initSignals()

		initViewport()

		initLogging()

		return true
	}

	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initializes the text-based user interface
	///
	/// Note that the text-based user interface can be disabled on the command line. In that case, this method does nothing.
	private func initViewport()
	{
		// Setup our text UI, if desired
		if commandLine.useTextUi
		{
			gLogger.trace("Initializing TextUI")

			viewportProvider = WhisperMediaViewportProvider()
		}
		else
		{
			gLogger.trace("TextUi disabled by user request, skipping")
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize signal handlers
	private func initSignals()
	{
		gLogger.trace("Initializing signals")

		trap(signum: .INT)   { _ in Whisper.instance.shutdown(because: "SIGINT received") }
		trap(signum: .ALRM)  { _ in Whisper.instance.shutdown(because: "SIGALRM received") }
		trap(signum: .PIPE)  { _ in Whisper.instance.shutdown(because: "SIGPIPE received") }
		trap(signum: .TERM)  { _ in Whisper.instance.shutdown(because: "SIGTERM received") }
		trap(signum: .STOP)  { _ in Whisper.instance.shutdown(because: "SIGSTOP received") }

		trap(signum: .QUIT)  { _ in Whisper.instance.onCrash(because: "SIGQUIT received") }
		trap(signum: .ILL)   { _ in Whisper.instance.onCrash(because: "SIGILL received") }
		trap(signum: .TRAP)  { _ in Whisper.instance.onCrash(because: "SIGTRAP received") }
		trap(signum: .ABRT)  { _ in Whisper.instance.onCrash(because: "SIGABRT received") }
		trap(signum: .EMT)   { _ in Whisper.instance.onCrash(because: "SIGEMT received") }
		trap(signum: .FPE)   { _ in Whisper.instance.onCrash(because: "SIGFPE received") }
		trap(signum: .BUS)   { _ in Whisper.instance.onCrash(because: "SIGBUS received") }
		trap(signum: .SEGV)  { _ in Whisper.instance.onCrash(because: "SIGSEGV received") }
		trap(signum: .SYS)   { _ in Whisper.instance.onCrash(because: "SIGSYS received") }

		trap(signum: .WINCH) { _ in Whisper.instance.viewportProvider?.setResizeRequested() }
	}

	// -----------------------------------------------------------------------------------------------------------------------------

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

		// Setup the logger
		if !gLogger.registerDevice(device: LogDeviceFile(logFileLocations: Config.logFileLocations, truncate: Config.logResetOnStart), logMasks: Config.logMasks)
		{
			gLogger.error("Unable to register file logging device")
		}

		// If we don't have a TextUI, then register the console device instead
		if viewportProvider == nil
		{
			if !gLogger.registerDevice(device: LogDeviceConsole(), logMasks: Config.logMasks)
			{
				gLogger.error("Unable to register console logging device")
			}
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
	}

	// -----------------------------------------------------------------------------------------------------------------------------

	/// Uninitialize all subsystems
	private func uninit()
	{
		if commandLine.updateConfigOnExit
		{
			if !Config.write()
			{
				gLogger.warn("Unable to write config file")
			}
		}

		var statsArray = viewportProvider?.statsText ?? ["-- NO STATS AVAILABLE --"]
		if !statsArray.isEmpty { statsArray[0] += "\n\n" }

		viewportProvider?.uninit() ?? print(PerfTimer.statsString())

		print("\n------------------------------------------------------------------------------------------------------\n")
		print(statsArray.joined())
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Commands from the outside world
	// -----------------------------------------------------------------------------------------------------------------------------

	public static func systemShutdown()
	{
		#if os(Linux)
			gLogger.info("Whisper.systemShutdown: Shutting down system")
			system("shutdown -h now")
		#else
			gLogger.warn("Whisper.systemShutdown: Command 'shutdown' not supported on this platform")
		#endif
	}

	public static func systemReboot()
	{
		#if os(Linux)
			gLogger.info("Whisper.systemReboot: Rebooting system")
			system("reboot")
		#else
			gLogger.warn("Whisper.systemReboot: Command 'reboot' not supported on this platform")
		#endif
	}

	public static func checkForUpdates()
	{
		gLogger.info("Whisper.checkForUpdates: Checking for updates")

		#if os(Linux)
			#if TARGET_ARCH_armv7
				gLogger.info(" > Requesting script.armv7.sh")
				system("curl -sSL <your update script here> | bash")
			#elseif TARGET_ARCH_armv6
				gLogger.info(" > Requesting script.armv6.sh")
				system("curl -sSL <your update script here> | bash")
			#else
				gLogger.warn("Whisper.checkForUpdates: Command 'checkForUpdates' not supported on this architecture (must be arvm6 or armv7)")
			#endif
		#else
			gLogger.warn("Whisper.checkForUpdates: Command 'checkForUpdates' not supported on this platform (must be linux)")
		#endif
	}

	// -----------------------------------------------------------------------------------------------------------------------------

	/// Handle a crash condition
	///
	/// This method is intended to be called from the signal handlers for SIGSEGV and other similar crashy conditions. The intention
	/// of this method is to perform a minimal shutdown and produce a final fatal error message.
	private func onCrash(because reason: String)
	{
		// Let's not get re-entrant
		if crashedFlag { return }
		crashedFlag = true

		// Bare minimum - terminate the UI so the terminal isn't left in a dirty state
		viewportProvider?.uninit()

#if os(Linux)
		let stderrout = stderr
#elseif os(macOS)
		let stderrout = __stderrp
#endif

		var callstack = [UnsafeMutableRawPointer?](repeating: nil, count: 128)
		let frames = nativeBacktrace(&callstack, Int32(callstack.count))

		// First we print to stderr
		fputs("CRASH: \(reason):\n", stderrout)
		if let symbols = nativeBacktraceSymbols(&callstack, frames)
		{
			for frame in 0..<Int(frames) where symbols[frame] != nil
			{
				fputs(" > [\(frame+1)/\(Int(frames))] \(String(cString: symbols[frame]!))\n", stderrout)
			}
			free(symbols)
		}

		// Next we try to log it
		gLogger.error("CRASH: \(reason):")
		if let symbols = nativeBacktraceSymbols(&callstack, frames)
		{
			for frame in 0..<Int(frames) where symbols[frame] != nil
			{
				gLogger.error("  > [\(frame+1)/\(Int(frames))] \(String(cString: symbols[frame]!))")
			}
			free(symbols)
		}

		// Finally, if we have a luma image, let's write it out
		if !(mediaProvider?.archiveFrame(baseName: "crash", async: false) ?? false)
		{
			gLogger.error("Unable to write Luma debug image for crash")
		}

		// Terminate :(
		abort()
	}
}
