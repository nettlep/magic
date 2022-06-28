//
//  VideoCapture.cpp
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

#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <cstddef>
#include <iostream>

#include "VideoCapture.h"
#include "VcosException.h"
#include "Logger.h"

extern "C"
{
	#include "bcm_host.h"

	#include "interface/vcsm/user-vcsm.h"
	#include "interface/mmal/mmal_queue.h"
	#include "interface/mmal/util/mmal_default_components.h"
	#include "interface/mmal/util/mmal_connection.h"
}

using namespace std;

// ---------------------------------------------------------------------------------------------------------------------------------
// Globals
// ---------------------------------------------------------------------------------------------------------------------------------

/// Our primary video capture manager
VideoCapture gVideoCaptureManager = VideoCapture();

// ---------------------------------------------------------------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------------------------------------------------------------

/// Construction
VideoCapture::VideoCapture()
	: mVideoInitialized(false), mLumaFrameReceiver(nullptr)
{
	// Do our one-time system initialization
	oneTimeInit();
}

/// Destruction
VideoCapture::~VideoCapture()
{
	uninitVideo();
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Capture control
// ---------------------------------------------------------------------------------------------------------------------------------

/// Starts a video capture at the given frame size and rate.
///
/// If `receiver` is set, then this callback receives every frame as it becomes available. In these cases, the circular
/// buffer is not used and polling functions will either do nothing or return empty results.
///
/// Throws VcosException on error
void VideoCapture::startCapture(unsigned int frameWidth, unsigned int frameHeight, unsigned int frameRate, NativeCaptureFrameReceiver receiver)
{
	initVideo(frameWidth, frameHeight, frameRate, receiver);

	MMAL_STATUS_T status = mmal_port_parameter_set_boolean(&mMmalVideoPort, MMAL_PARAMETER_CAPTURE, 1);
	if (status != MMAL_SUCCESS)
	{
		throw VcosException(status, "Unable to start capture");
	}

	Logger::trace("*** Beginning live video capture");
	Logger::trace(SSTR << "    Frame info: " << frameWidth << "x" << frameHeight << "@" << frameRate << "Hz");
}

/// Stop a capture
///
/// Throws VcosException on error
void VideoCapture::stopCapture()
{
	MMAL_STATUS_T status = mmal_port_parameter_set_boolean(&mMmalVideoPort, MMAL_PARAMETER_CAPTURE, 0);
	if (status != MMAL_SUCCESS)
	{
		throw VcosException(status, "Unable to stop the active capture");
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------------------------------------------------------------

/// Performs various one-time initializations for hardware interfaces. Calling this method multiple times will do no harm as this
/// method will only perform those initializations which have not yet been performed (i.e., those that failed in previous attempts.)
///
/// Throws VcosException on error
void VideoCapture::oneTimeInit()
{
	static bool bcmOneTimeInitialized;
	if (!bcmOneTimeInitialized)
	{
		bcm_host_init();

		bcmOneTimeInitialized = true;
	}

	static bool vcsmOneTimeInitialized;
	if (!vcsmOneTimeInitialized)
	{
		if (vcsm_init() == -1)
		{
			throw VcosException(MMAL_ENOSYS, "Unable to init VCSM - possibly need root?");
		}

		vcsmOneTimeInitialized = true;
	}
}

/// Initialize the video capture
///
/// This method should not be called directly - see `startCapture()`
///
/// If `receiver` is set, then this callback receives every frame as it becomes available. In these cases, the circular
/// buffer is not used and polling functions will either do nothing or return empty results.
///
/// Throws VcosException on error
void VideoCapture::initVideo(unsigned int frameWidth, unsigned int frameHeight, unsigned int frameRate, NativeCaptureFrameReceiver receiver)
{
	// Ensure we've initialized
	oneTimeInit();

	if (mVideoInitialized)
	{
		return;
	}

	// Initialize our state information structure
	mFrameWidth = frameWidth;
	mFrameHeight = frameHeight;
	mFrameRateHz = frameRate;
	mpMmalCamComponent = nullptr;
	mpMmalVideoPortPool = nullptr;
	memset(&mMmalVideoPort, 0, sizeof(mMmalVideoPort));
	memset(&mVideoParameters, 0, sizeof(mVideoParameters));
	mCameraNum = 0;
	mUseCameraControlCallback = 0;
	mSensorMode = 0;
	mLumaFrameReceiver = receiver;

	// Set up the videoParameters to default
	mVideoParameters.setDefaults();

	// Set up our camera component
	createCameraComponent();

	try
	{
		// Our main data storage vessel..
		MMAL_PORT_T *mmalVideoPort = mpMmalCamComponent->output[kMmalCameraVideoPort];

		// Our state data is our user data
		mmalVideoPort->userdata = (struct MMAL_PORT_USERDATA_T *) this;

		// Enable the camera video port with a callback function
		MMAL_STATUS_T status = mmal_port_enable(mmalVideoPort, cameraBufferCallback);
		if (status != MMAL_SUCCESS)
		{
			throw VcosException(status, "Failed to setup camera output");
		}

		// Send all the buffers to the camera video port
		int num = mmal_queue_length(mpMmalVideoPortPool->queue);
		for (int i = 0; i < num; i++)
		{
			MMAL_BUFFER_HEADER_T *buffer = mmal_queue_get(mpMmalVideoPortPool->queue);

			if (!buffer)
			{
				throw VcosException(MMAL_ENOMEM, SSTR << "Unable to get a required buffer " << i << " from pool queue");
			}

			MMAL_STATUS_T status = mmal_port_send_buffer(mmalVideoPort, buffer);
			if (status != MMAL_SUCCESS)
			{
				throw VcosException(MMAL_ENOSYS, SSTR << "Unable to send a buffer to camera video port (" << i << ")");
			}
		}

		// Let's keep a copy of this...
		mMmalVideoPort = *mmalVideoPort;

		// If we have don't have receiver, allocate our circular image buffer
		if (nullptr == mLumaFrameReceiver)
		{
			mpCircularImageBuffer = new CircularImageBuffer<LumaSample>(mFrameWidth, mFrameHeight, kCircularImageBufferCapacity);
		}
	}
	catch(VcosException &ex)
	{
		uninitVideo();

		// rethrow
		throw;
	}

	mVideoInitialized = true;
}

/// Halt video capture
///
/// This method should not be called directly - see `startCapture()`
void VideoCapture::uninitVideo()
{
	MMAL_COMPONENT_T *camera = mpMmalCamComponent;
	if (camera)
	{
		// Get the video port for the camera
		MMAL_PORT_T *videoPort = camera->output[kMmalCameraVideoPort];

		// Disable the component
		mmal_component_disable(camera);

		if (videoPort)
		{
			if (videoPort->is_enabled)
			{
				// Enable the camera video port with a callback function
				MMAL_STATUS_T status = mmal_port_disable(videoPort);
				if (status != MMAL_SUCCESS)
				{
					// Do nothing
					// throw VcosException(status, "Failed to disable the video port");
				}
			}

			// Destroy the video port pool
			mmal_port_pool_destroy(videoPort, mpMmalVideoPortPool);
		}

		// Destroy the camera component
		MMAL_STATUS_T status = mmal_component_destroy(camera);
		if (status != MMAL_SUCCESS)
		{
			// Do nothing
			// throw VcosException(status, "Failed to destroy the camera component");
		}

		mpMmalCamComponent = nullptr;
	}

	// Cleanup our circular image buffer
	if (mpCircularImageBuffer)
	{
		delete mpCircularImageBuffer;
		mpCircularImageBuffer = nullptr;
	}

	// Clear this out
	mLumaFrameReceiver = nullptr;

	// We're no longer initialized
	mVideoInitialized = false;
}

/// Create the camera component, set up its ports
///
/// Throws VcosException on error
void VideoCapture::createCameraComponent()
{
	MMAL_COMPONENT_T *camera = 0;

	try
	{
		// Create the component
		MMAL_STATUS_T status = mmal_component_create(MMAL_COMPONENT_DEFAULT_CAMERA, &camera);

		if (status != MMAL_SUCCESS)
		{
			throw VcosException(status, "Failed to create camera component");
		}

		// Select our camera device (always 0)
		MMAL_PARAMETER_INT32_T cameraNumParam = {{MMAL_PARAMETER_CAMERA_NUM, sizeof(cameraNumParam)}, mCameraNum};
		status = mmal_port_parameter_set(camera->control, &cameraNumParam.hdr);
		if (status != MMAL_SUCCESS)
		{
			throw VcosException(status, "Could not select camera");
		}

		if (!camera->output_num)
		{
			throw VcosException(MMAL_ENOSYS, "Camera doesn't have output ports");
		}

		status = mmal_port_parameter_set_uint32(camera->control, MMAL_PARAMETER_CAMERA_CUSTOM_SENSOR_CONFIG, mSensorMode);

		if (status != MMAL_SUCCESS)
		{
			throw VcosException(status, "Could not set sensor mode");
		}

		if (mUseCameraControlCallback)
		{
			MMAL_PARAMETER_CHANGE_EVENT_REQUEST_T changeEventRequest =
			{
				{
					MMAL_PARAMETER_CHANGE_EVENT_REQUEST, 
					sizeof(MMAL_PARAMETER_CHANGE_EVENT_REQUEST_T)
				},
				MMAL_PARAMETER_CAMERA_SETTINGS,
				1
			};

			status = mmal_port_parameter_set(camera->control, &changeEventRequest.hdr);
			if (status != MMAL_SUCCESS)
			{
				throw VcosException(status, "No camera settings events");
			}
		}

		// Set the encode format on the video port
		MMAL_PORT_T *videoPort = camera->output[kMmalCameraVideoPort];
		MMAL_ES_FORMAT_T *format = videoPort->format;

		if(mVideoParameters.shutterSpeed > 6000000)
		{
			MMAL_PARAMETER_FPS_RANGE_T fpsRangeParam = {{MMAL_PARAMETER_FPS_RANGE, sizeof(fpsRangeParam)}, { 50, 1000 }, {166, 1000}};
			mmal_port_parameter_set(videoPort, &fpsRangeParam.hdr);
		}
		else if(mVideoParameters.shutterSpeed > 1000000)
		{
			MMAL_PARAMETER_FPS_RANGE_T fpsRangeParam = {{MMAL_PARAMETER_FPS_RANGE, sizeof(fpsRangeParam)}, { 167, 1000 }, {999, 1000}};
			mmal_port_parameter_set(videoPort, &fpsRangeParam.hdr);
		}

		format->encoding = MMAL_ENCODING_I420;
		format->encoding_variant = MMAL_ENCODING_I420;

		format->es->video.width = VCOS_ALIGN_UP(mFrameWidth, 32);
		format->es->video.height = VCOS_ALIGN_UP(mFrameHeight, 16);
		format->es->video.crop.x = 0;
		format->es->video.crop.y = 0;
		format->es->video.crop.width = mFrameWidth;
		format->es->video.crop.height = mFrameHeight;
		format->es->video.frame_rate.num = mFrameRateHz;
		format->es->video.frame_rate.den = 1;

		status = mmal_port_format_commit(videoPort);

		if (status != MMAL_SUCCESS)
		{
			throw VcosException(status, "Camera video format couldn't be set");
		}

		// Ensure there are enough buffers to avoid dropping frames
		if (videoPort->buffer_num < kVideoOutputBufferCount)
		{
			videoPort->buffer_num = kVideoOutputBufferCount;
		}

		status = mmal_port_parameter_set_boolean(videoPort, MMAL_PARAMETER_ZERO_COPY, MMAL_TRUE);
		if (status != MMAL_SUCCESS)
		{
			throw VcosException(status, "Failed to select zero copy");
		}

		// Enable component
		status = mmal_component_enable(camera);

		if (status != MMAL_SUCCESS)
		{
			throw VcosException(status, "Camera component couldn't be enabled");
		}

		mVideoParameters.setAllParameters(camera);

		// Create pool of buffer headers for the output port to consume
		MMAL_POOL_T *pool = mmal_port_pool_create(videoPort, videoPort->buffer_num, videoPort->buffer_size);

		if (!pool)
		{
			throw VcosException(MMAL_ENOMEM, SSTR << "Failed to create buffer header pool for camera video port " << videoPort->name);
		}

		mpMmalVideoPortPool = pool;
		mpMmalCamComponent = camera;
	}
	catch(VcosException &ex)
	{
		if (camera)
		{
			mmal_component_destroy(camera);
		}

		// rethrow
		throw;
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Frame management
// ---------------------------------------------------------------------------------------------------------------------------------

/// Callback for buffer containing captured image data (YUV)
void VideoCapture::cameraBufferCallback(MMAL_PORT_T *port, MMAL_BUFFER_HEADER_T *buffer)
{
	static bool noReentryFlag = false;

	// Don't re-enter this method
	if (noReentryFlag) return;

	// Set the flag so they know we're busy
	noReentryFlag = true;

	try
	{
		MMAL_BUFFER_HEADER_T *newBuffer;
		static int64_t baseTime = -1;

		// All our times based on the receipt of the first callback
		if (baseTime == -1)
		{
			baseTime = vcos_getmicrosecs64() / 1000;
		}

		if (port->userdata)
		{
			// Get our state data
			VideoCapture &state = *((VideoCapture *)port->userdata);

			// Lock the buffer
			mmal_buffer_header_mem_lock(buffer);
			{
				NativeLumaBuffer imageBuffer = reinterpret_cast<NativeLumaBuffer>(buffer->data);

				// Add it to our circular buffer
				if (state.mpCircularImageBuffer)
				{
					state.mpCircularImageBuffer->add(imageBuffer);
				}

				// Our image dimensions
				unsigned int w = port->format->es->video.width;
				unsigned int h = vcos_min(port->format->es->video.height, state.mFrameHeight);

				// If we have a receiver, notify them
				if (nullptr != state.mLumaFrameReceiver)
				{
					(*state.mLumaFrameReceiver)(imageBuffer, w, h);
				}
			}
			mmal_buffer_header_mem_unlock(buffer);

			// release buffer back to the pool
			mmal_buffer_header_release(buffer);

			// and send one back to the port (if still open)
			if (port->is_enabled)
			{
				MMAL_STATUS_T status;

				newBuffer = mmal_queue_get(state.mpMmalVideoPortPool->queue);

				if (newBuffer)
				{
					status = mmal_port_send_buffer(port, newBuffer);
				}

				if (!newBuffer || status != MMAL_SUCCESS)
				{
					Logger::error("Unable to return a buffer to the camera port");
				}
			}
		}
		else
		{
			// release buffer back to the pool
			mmal_buffer_header_release(buffer);

			Logger::error("Received a camera buffer callback with no state");
		}
	}
	catch(std::exception &ex)
	{
		Logger::error(SSTR << "Caught unexpected exception during video capture callback: " << ex.what());
	}
	catch(...)
	{
		Logger::error(SSTR << "Caught unknown exception during video capture callback");
	}

	// It's OK to enter again
	noReentryFlag = false;
}

#endif // defined(USE_MMAL)
