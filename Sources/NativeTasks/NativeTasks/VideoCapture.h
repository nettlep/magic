//
//  VideoCapture.h
//  NativeTasks
//
//  Created by Paul Nettle on 5/13/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#if defined(USE_MMAL)

#pragma once

#include <vector>
#include "VideoParameters.h"
#include "CircularImageBuffer.h"
#include "include/NativeInterface.h"

extern "C"
{
	#include "interface/mmal/util/mmal_util.h"
}

/// Video capture management class
///
/// Performs initialization and capture of live video data
class VideoCapture
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Standard port setting for the camera component
	private: static const int kMmalCameraPreviewPort = 0;
	private: static const int kMmalCameraVideoPort = 1;
	private: static const int kMmalCameraCapturePort = 2;

	/// Video render needs at least 2 buffers
	private: static const int kVideoOutputBufferCount = 2;

	/// Circular Image Buffer capacity
	private: static const unsigned int kCircularImageBufferCapacity = 3;

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Our circular image buffer
	public: CircularImageBuffer<LumaSample> *circularImageBuffer() { return mpCircularImageBuffer; }
	private: CircularImageBuffer<LumaSample> *mpCircularImageBuffer;

	// -----------------------------------------------------------------------------------------------------------------------------
	// Construction
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Construction
	public: VideoCapture();

	/// Destruction
	public: ~VideoCapture();

	// -----------------------------------------------------------------------------------------------------------------------------
	// Capture control
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Starts a video capture at the given frame size and rate.
	///
	/// If `receiver` is set, then this callback receives every frame as it becomes available. In these cases, the circular
	/// buffer is not used and polling functions will either do nothing or return empty results.
	///
	/// Throws VcosException on error
	public: void startCapture(unsigned int frameWidth, unsigned int frameHeight, unsigned int frameRate, NativeCaptureFrameReceiver receiver);

	/// Stop a capture
	///
	/// Throws VcosException on error
	public: void stopCapture();

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Performs various one-time initializations for hardware interfaces. Calling this method multiple times will do no harm as this
	/// method will only perform those initializations which have not yet been performed (i.e., those that failed in previous attempts.)
	///
	/// Throws VcosException on error
	private: void oneTimeInit();

	/// Returns camera video port
	///
	/// Throws VcosException on error
	private: void initVideo(unsigned int frameWidth, unsigned int frameHeight, unsigned int frameRate, NativeCaptureFrameReceiver receiver);

	/// Destroy the camera component
	///
	/// Throws VcosException on error
	private: void uninitVideo();

	/// Create the camera component, set up its ports
	///
	/// Throws VcosException on error
	private: void createCameraComponent();

	// -----------------------------------------------------------------------------------------------------------------------------
	// Frame management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Callback for buffer containing captured image data (YUV)
	private: static void cameraBufferCallback(MMAL_PORT_T *port, MMAL_BUFFER_HEADER_T *buffer);

	// -----------------------------------------------------------------------------------------------------------------------------
	// Data members
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Video capture frame width
	private: unsigned int mFrameWidth;

	/// Video capture frame height
	private: unsigned int mFrameHeight;

	/// Video capture frame rate (in Hz)
	private: unsigned int mFrameRateHz;

	/// MMAL camera component
	private: MMAL_COMPONENT_T *mpMmalCamComponent;

	/// MMAL pool of buffers used by camera video port
	private: MMAL_POOL_T *mpMmalVideoPortPool;

	/// MMAL video port
	private: MMAL_PORT_T mMmalVideoPort;

	/// Our local camera parameters
	private: VideoParameters mVideoParameters;

	/// Camera number
	private: int mCameraNum;

	/// Request settings from the camera
	private: int mUseCameraControlCallback;

	/// Sensor mode. 0=auto. Check docs/forum for modes selected by other values
	private: int mSensorMode;

	/// Have we been initialized?
	private: bool mVideoInitialized;

	/// Video capture receiver
	private: NativeCaptureFrameReceiver mLumaFrameReceiver;
};

/// Our primary video capture manager
extern VideoCapture gVideoCaptureManager;

#endif // defined(USE_MMAL)
