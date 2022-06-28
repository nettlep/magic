//
//  AbraCaptureMediaProvider.swift
//  Abra
//
//  Created by Paul Nettle on 5/9/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import AVFoundation
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
import MobileCoreServices
import SeerIOS
import MinionIOS
import NativeTasksIOS
#else
import Seer
import Minion
import NativeTasks
#endif

internal final class AbraCaptureMediaProvider: NSObject, MediaProvider, AVCaptureVideoDataOutputSampleBufferDelegate
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Types
	// -----------------------------------------------------------------------------------------------------------------------------

	struct CameraDevice: Identifiable
	{
		var id: String { return name }

		var name: String
		var type: AVCaptureDevice.DeviceType
		var position: AVCaptureDevice.Position

		var typeString: String
		{
			var typeString = type.rawValue
			let typePrefix = "AVCaptureDeviceType"
			if typeString.starts(with: typePrefix)
			{
				typeString = String(typeString.suffix(typeString.length() - typePrefix.length()))
			}

			return typeString
		}

		var positionString: String
		{
			var positionString: String
			switch position
			{
			case .front:
				positionString = "Front"
			case .back:
				positionString = "Back"
			default:
				positionString = "Unknown"
			}

			return positionString
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// General properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Singleton interface
	private static var _shared: AbraCaptureMediaProvider?
	static var shared: AbraCaptureMediaProvider
	{
		get
		{
			if _shared == nil
			{
				_shared = AbraCaptureMediaProvider()
			}

			return _shared!
		}
		set
		{
			assert(_shared != nil)
		}
	}

	/// Media consumer (where our decoded frames are sent for processing)
	private var mediaConsumer: MediaConsumer?

	/// The capture session which controls the entire capture process
	private let captureSession = AVCaptureSession()

	/// Used to display video output to the viewport
	private var videoOutput = AVCaptureVideoDataOutput()

	/// Our luma buffer (raw camera data)
	private var lumaBuffer: LumaBuffer?

	/// Our preview layer, needed to ensure the camera is active for getting camera pixels
	private var previewLayer: AVCaptureVideoPreviewLayer?

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

	/// Camera devices that are found at init time
	var cameraDevices = [CameraDevice]()

	/// The active camera device, if one is set
	var activeCameraDevice: CameraDevice?

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a MediaProvider
	override init()
	{
		super.init()

		initCameraDevices()
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

		// Attempt to start capturing video
		if !startCapture(delegate: self)
		{
			gLogger.error("Failed to start camera capture")
			return
		}
	}

	/// Stop camera capture
	func stop()
	{
		// Stop capturing video
		stopCapture()
	}

	/// Waits for the media provider to shut down
	func waitUntilStopped()
	{
		gLogger.error("AbraCaptureMediaProvider does not support waitUntilStopped()")
		return
	}

	/// Restart the current media file at the beginning
	func restart()
	{
		// Not available in this implementation
		//
		// Video capture has no media
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
		// Not available in this implementation
		return false
	}

	/// This method must be called whenever media is changed, in order to allow the system to manage a new input resolution
	func onMediaChanged(to path: PathString, withSize size: IVector)
	{
		(self as MediaProvider).onMediaChanged(to: path, withSize: size)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Private implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	private func startCapture(delegate: AVCaptureVideoDataOutputSampleBufferDelegate) -> Bool
	{
		// Is video capture supported?
		if !isCaptureDeviceSupported()
		{
			gLogger.error("No usable camera!")
			return false
		}

		// Find a valid device (rear video camera)
		guard let device = getCaptureDevice(captureSession: captureSession) else
		{
			gLogger.error("Failed to find a valid capture device")
			return false
		}

		NotificationCenter.default.addObserver(self,
											   selector: #selector(sessionWasInterrupted),
											   name: .AVCaptureSessionWasInterrupted,
											   object: captureSession)
		NotificationCenter.default.addObserver(self,
											   selector: #selector(sessionInterruptionEnded),
											   name: .AVCaptureSessionInterruptionEnded,
											   object: captureSession)

		NotificationCenter.default.addObserver(self,
											   selector: #selector(sessionRuntimeError),
											   name: .AVCaptureSessionRuntimeError,
											   object: captureSession)

		// These nested dispatches are odd, but the idea is that there it is important to wait for the capture session
		// fully start before creating the preview layer, or there will be a long delay in starting the new camera device.
		//
		// Thanks to https://stackoverflow.com/questions/21949080/camera-feed-slow-to-load-with-avcapturesession-on-ios-how-can-i-speed-it-up
		DispatchQueue.global().async
		{
			// Set the device and start capturing
			self.captureSession.addInput(device)
			self.captureSession.startRunning()

			DispatchQueue.main.async
			{
				// We need a preview layer in order to capture live image data, but we just hold onto it and don't do anything with it
				self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)

				DispatchQueue.global().async
				{
					// We don't actually need the preview layer embedded in the view - we'll do that ourselves
					// previewLayer.frame = view.bounds
					// view.layer.addSublayer(previewLayer)

					// Setup to capture the video output
					let serialQueue = DispatchQueue(label: "com.paulnettle.abra.captures", qos: .userInteractive)
					self.videoOutput.setSampleBufferDelegate(delegate, queue: serialQueue)
					if !self.captureSession.canAddOutput(self.videoOutput)
					{
						gLogger.error("Unable to set the output for the capture session")
						return
					}

					self.captureSession.addOutput(self.videoOutput)
				}
			}
		}

		return true
	}

	@objc public func sessionWasInterrupted(_: NSNotification)
	{
//		if reason == .audioDeviceInUseByAnotherClient || reason == .videoDeviceInUseByAnotherClient
//		{
//			showResumeButton = true
//		}
//		else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps
//		{
//			// Fade-in a label to inform the user that the camera is unavailable.
//			cameraUnavailableLabel.alpha = 0
//			cameraUnavailableLabel.isHidden = false
//			UIView.animate(withDuration: 0.25)
//			{
//				self.cameraUnavailableLabel.alpha = 1
//			}
//		}
//		else if reason == .videoDeviceNotAvailableDueToSystemPressure
//		{
//			print("Session stopped running due to shutdown system pressure level.")
//		}
	}

	@objc public func sessionInterruptionEnded(_: NSNotification)
	{
	}

	@objc public func sessionRuntimeError(_: NSNotification)
	{
//		// If media services were reset, and the last start succeeded, restart the session.
//		if error.code == .mediaServicesWereReset
//		{
//			sessionQueue.async
//			{
//				if self.isSessionRunning
//				{
//					self.session.startRunning()
//					self.isSessionRunning = self.session.isRunning
//				}
//				else
//				{
//					DispatchQueue.main.async
//					{
//						self.resumeButton.isHidden = false
//					}
//				}
//			}
//		}
//		else
//		{
//			resumeButton.isHidden = false
//		}
	}

	private func stopCapture()
	{
		// Set the device and start capturing
		for input in captureSession.inputs
		{
			captureSession.removeInput(input)
		}
		captureSession.stopRunning()

		// Remove our preview layer
		previewLayer = nil

		for output in captureSession.outputs
		{
			captureSession.removeOutput(output)
		}
	}

	private func isCaptureDeviceSupported() -> Bool
	{
#if os(iOS)
		if !UIImagePickerController.isSourceTypeAvailable(.camera)
		{
			gLogger.error("No camera source avaiable")
			return false
		}

		guard let availableMediaTypes = UIImagePickerController.availableMediaTypes(for: .camera) else
		{
			gLogger.error("No camera media types avaiable")
			return false
		}

		if !availableMediaTypes.contains("public.movie") // (UTTypeMovie as String)
		{
			gLogger.error("No video camera avaiable")
			return false
		}

		if !UIImagePickerController.isCameraDeviceAvailable(.rear)
		{
			gLogger.error("No rear camera avaiable")
			return false
		}
#else
		// Anything to do here for Mac support?
#endif

		return true
	}

	private func initCameraDevices()
	{
		cameraDevices = [CameraDevice]()

		#if os(iOS)
		let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTripleCamera, .builtInTelephotoCamera, .builtInDualWideCamera, .builtInUltraWideCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
		#else
		let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
		#endif
		for device in discoverySession.devices
		{
			do
			{
				try device.lockForConfiguration()
				defer
				{
					device.unlockForConfiguration()
					captureSession.sessionPreset = .high
				}

				let newDevice = CameraDevice(name: device.localizedName, type: device.deviceType, position: device.position)
				cameraDevices.append(newDevice)
			}
			catch
			{
				gLogger.warn("AbraCaptureMediaProvider.initCameraDevices: Device discovery error: \(error.localizedDescription)")
			}
		}

		if cameraDevices.count == 0
		{
			gLogger.warn("AbraCaptureMediaProvider.initCameraDevices: No devices found")
			return
		}

		// Set the active device from preferences
		let defaultDeviceName = Preferences.shared.activeCameraDeviceName ?? cameraDevices[0].name

		setCameraDevice(deviceName: defaultDeviceName)
	}

	func findCameraDevice(byDeviceName name: String) -> CameraDevice?
	{
		return cameraDevices.first(where: {$0.name == name})
	}

	func setCameraDevice(deviceName: String)
	{
		if cameraDevices.count == 0
		{
			gLogger.error("AbraCaptureMediaProvider.setCameraDevice(deviceName): Unable to set camera device - no devices!")
			return
		}

		activeCameraDevice = findCameraDevice(byDeviceName: deviceName)

		if activeCameraDevice == nil
		{
			gLogger.error("AbraCaptureMediaProvider.setCameraDevice(deviceName): Unable to locate camera device named '\(deviceName)', using first device ('\(cameraDevices[0].name)') instead")
			activeCameraDevice = cameraDevices[0]
		}

		// Update preferences
		Preferences.shared.activeCameraDeviceName = activeCameraDevice!.name
	}

	func restartCapture()
	{
		guard let mediaConsumer = self.mediaConsumer else
		{
			gLogger.error("AbraCaptureMediaProvider.setCameraDevice(device): Unable to set the camera device - the capture must be initially started")
			return
		}

		stop()
		start(mediaConsumer: mediaConsumer)
	}

	/// Finds a valid device
	///
	/// The device must support continuous auto-focus and capable of being added to `captureSession`
	private func getCaptureDevice(captureSession: AVCaptureSession) -> AVCaptureDeviceInput?
	{
		guard let activeCameraDevice = activeCameraDevice else
		{
			gLogger.warn("AbraCaptureMediaProvider.getCaptureDevice: no active camera device")
			return nil
		}

		// Find a valid device (rear video camera)
		let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [activeCameraDevice.type], mediaType: .video, position: activeCameraDevice.position)
		for device in discoverySession.devices
		{
			do
			{
				try device.lockForConfiguration()
				defer
				{
					device.unlockForConfiguration()
					captureSession.sessionPreset = .high
				}

				if device.isFocusModeSupported(.autoFocus) || device.isFocusModeSupported(.continuousAutoFocus)
				{
					// Set the focus mode to the center of the view and keep it that way
					if device.isFocusPointOfInterestSupported
					{
						device.focusPointOfInterest = CGPoint(x: CGFloat(0.5), y: CGFloat(0.5))
					}
					if device.isFocusModeSupported(.continuousAutoFocus)
					{
						device.focusMode = .continuousAutoFocus
					}
					else
					{
						device.focusMode = .autoFocus
					}
				}

				if device.isExposurePointOfInterestSupported
				{
					device.exposurePointOfInterest = CGPoint(x: CGFloat(0.5), y: CGFloat(0.5))
				}

				if device.isExposureModeSupported(.continuousAutoExposure)
				{
					device.exposureMode = .continuousAutoExposure
				}
				else if device.isExposureModeSupported(.autoExpose)
				{
					device.exposureMode = .autoExpose
				}

				if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance)
				{
					device.whiteBalanceMode = .continuousAutoWhiteBalance
				}
				else if device.isWhiteBalanceModeSupported(.autoWhiteBalance)
				{
					device.whiteBalanceMode = .autoWhiteBalance
				}

				#if os(iOS)
				if device.isLowLightBoostSupported
				{
					device.automaticallyEnablesLowLightBoostWhenAvailable = true
				}

				// This exposure target bias value is a bit of an unknown
				// A value of 0 is good for normal use, but in order to see
				// UV (brightly illuminated marks) then a value of 8 seems
				// to be needed.
				device.setExposureTargetBias(0, completionHandler: nil)
				device.automaticallyAdjustsVideoHDREnabled = true
				#endif

				let captureDevice = try AVCaptureDeviceInput(device: device)
				if captureSession.canAddInput(captureDevice)
				{
					gLogger.info("AbraCaptureMediaProvider.getCaptureDevice: Using device: \(activeCameraDevice.name) (\(device.activeFormat.formatDescription.mediaType)/\(device.activeFormat.formatDescription.mediaSubType))")
					return captureDevice
				}
			}
			catch
			{
				gLogger.warn("AbraCaptureMediaProvider.getCaptureDevice: Device discovery error: \(error.localizedDescription)")
			}
		}

		return nil
	}

	/// This method provides the functionality for implementing `AVCaptureVideoDataOutputSampleBufferDelegate`
	internal func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
	{
		let _track_ = PerfTimer.ScopedTrack(name: "Full frame"); _track_.use()

		if !updateLumaBuffer(sampleBuffer: sampleBuffer)
		{
			gLogger.error("Failed to update luma buffer")
			return
		}

		guard let lumaBuffer = lumaBuffer else
		{
			gLogger.error("Camera has no luma buffer")
			return
		}

		if !(mediaConsumer?.shouldScan() ?? false)
		{
			return
		}

		// Make sure we have a valid code definition
		guard let codeDefinition = Config.searchCodeDefinition else
		{
			gLogger.error("No code definition set, unable to process frame")
			return
		}

		gLogger.frame(String(format: "    >> Received capture frame of %dx%d", lumaBuffer.width, lumaBuffer.height))

		preFrameCallback?()
		preFrameCallback = nil

		defer
		{
			postFrameCallback?()
			postFrameCallback = nil
		}

		// Scan the image
		mediaConsumer?.processFrame(lumaBuffer: lumaBuffer, codeDefinition: codeDefinition)
	}

	private func updateLumaBuffer(sampleBuffer: CMSampleBuffer) -> Bool
	{
		guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else
		{
			gLogger.error("Unable to get pixel buffer")
			return false
		}

		if CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) != kCVReturnSuccess
		{
			gLogger.error("Unable to lock pixel buffer")
			return false
		}

		defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

		// Get the base address of the luma plane
		guard let lumaBaseAddress: UnsafeMutableRawPointer = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else
		{
			gLogger.error("Unable to get plane 0")
			return false
		}

		// Update the pixels in the frame buffer
		let width = CVPixelBufferGetWidth(pixelBuffer)
		let height = CVPixelBufferGetHeight(pixelBuffer)
		let byteBuffer = lumaBaseAddress.assumingMemoryBound(to: UInt8.self)

		// Allocate a new luma buffer if we need to
		if lumaBuffer == nil || lumaBuffer!.width != width || lumaBuffer!.height != height
		{
			lumaBuffer = LumaBuffer(width: width, height: height)
		}

		// Found on mac
		//
		// Component Y'CbCr 8-bit 4:2:2, ordered Cb Y'0 Cr Y'1
		if sampleBuffer.formatDescription!.mediaSubType == .init(rawValue: kCVPixelFormatType_422YpCbCr8)
		{
			// Copy/convert our 2vuy buffer into a standard luma buffer
			lumaBuffer?.copy(from2vuyBuffer: byteBuffer)
		}
		// Found on iOS
		//
		// Bi-Planar Component Y'CbCr 8-bit 4:2:0, video-range (luma=[16,235] chroma=[16,240]).
		// baseAddr points to a big-endian CVPlanarPixelBufferInfo_YCbCrBiPlanar struct
		else if sampleBuffer.formatDescription!.mediaSubType == .init(rawValue: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
		{
			// Since the format includes an 8-bit luma buffer at the beginning, we can just pass the entire buffer
			// through and the rest will be ignored.
			lumaBuffer?.copy(from: byteBuffer, width: width, height: height)
		}
		else
		{
			gLogger.error("Unsupported pixel buffer format: \(sampleBuffer.formatDescription!.mediaType)/\(sampleBuffer.formatDescription!.mediaSubType)")
		}

		return true
	}
}
