//
//  NativeInterface.h
//  NativeTasks
//
//  Created by Paul Nettle on 5/22/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#pragma once

#include "NativeTaskTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif //__cplusplus

	// -----------------------------------------------------------------------------------------------------------------------------
	//  ____                       _ _
	// / ___|  ___  ___ _   _ _ __(_) |_ _   _
	// \___ \ / _ \/ __| | | | '__| | __| | | |
	//  ___) |  __/ (__| |_| | |  | | |_| |_| |
	// |____/ \___|\___|\__,_|_|  |_|\__|\__, |
	//                                   |___/
	//
	// -----------------------------------------------------------------------------------------------------------------------------

#if defined(__linux__)

	/// Returns a string with the permanent ethernet MAC addresses
	const char *nativeSecDescriptor(const char *name);

#endif // defined(__linux__)

	// -----------------------------------------------------------------------------------------------------------------------------
	//  ____             _    _
	// | __ )  __ _  ___| | _| |_ _ __ __ _  ___ ___  ___
	// |  _ \ / _` |/ __| |/ / __| '__/ _` |/ __/ _ \/ __|
	// | |_) | (_| | (__|   <| |_| | | (_| | (_|  __/\__ \
	// |____/ \__,_|\___|_|\_\\__|_|  \__,_|\___\___||___/
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Passthrough function for `char **backtrace(void** array, int size)`
	/// (see manpage or execinfo.h)
	///
	/// Writes the function return addresses of the current call stack to the array of pointers referenced by array.
	///
	/// At most, size pointers are written.  The number of pointers actually written to array is returned.
	int nativeBacktrace(void **array, int size);

	/// Passthrough function for `char **backtrace_symbols(void* const* array, int size)`
	/// (see manpage or execinfo.h)
	///
	/// Attempts to transform a call stack obtained by backtrace() into an array of human-readable strings using `dladdr()`. The
	/// array of strings returned has size elements.  It is allocated using `malloc()` and should be released using `free()`.
	/// There is no need to free the individual strings in the array.
	char **nativeBacktraceSymbols(void * const *array, int size);

	/// Passthrough function for `void backtrace_symbols_fd(void* const* array, int size, int fd)`
	/// (see manpage or execinfo.h)
	///
	/// Performs the same operation as `backtrace_symbols()`, but the resulting strings are immediately written to the file
	/// descriptor fd, and are not returned.
	void nativeBacktraceSymbolsFd(void * const *array, int size, int fd);

	// -----------------------------------------------------------------------------------------------------------------------------
	//  ___                               ____                              _             
	// |_ _|_ __ ___   __ _  __ _  ___   / ___|___  _ ____   _____ _ __ ___(_) ___  _ __  
	//  | || '_ ` _ \ / _` |/ _` |/ _ \ | |   / _ \| '_ \ \ / / _ \ '__/ __| |/ _ \| '_ \
	//  | || | | | | | (_| | (_| |  __/ | |__| (_) | | | \ V /  __/ |  \__ \ | (_) | | | |
	// |___|_| |_| |_|\__,_|\__, |\___|  \____\___/|_| |_|\_/ \___|_|  |___/_|\___/|_| |_|
	//                      |___/                                                         
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Copies image `src` (2vuy) to `dst` image (8-bit monochrome)
	///
	/// Note that both `src` is a 16-bit format and must contain at least `width` * `height` * `2` elements, while `dst` must contain at least `width` * `height` elements
	void nativeCopy2vuyToLuma(const NativeLumaBuffer src, NativeLumaBuffer dst, uint32_t width, uint32_t height);

	/// Copies image `src` (8-bit monochrome) to `dst` image (32-bit ARGB) with 8-bit -> 32-bit monochrome conversion
	///
	/// Note that both `src` and `dst` must contain at least `width` * `height` elements each
	void nativeCopyLumaToColor(const NativeLumaBuffer src, NativeColorBuffer dst, uint32_t width, uint32_t height);

	/// Copies image `src` (32-bit ARGB) to `dst` image (8-bit monochrome) with 32-bit -> 8-bit monochrome conversion
	///
	/// Note that both `src` and `dst` must contain at least `width` * `height` elements each
	void nativeCopyColorToLuma(const NativeColorBuffer src, NativeLumaBuffer dst, uint32_t width, uint32_t height);

	/// Resamples 8-bit monochrome image `src` to `dst` with nearest-neighbor sampling
	void nativeResampleNearestNeighborLuma(const NativeLumaBuffer src, uint32_t srcWidth, uint32_t srcHeight, NativeLumaBuffer dst, uint32_t dstWidth, uint32_t dstHeight);

	/// Resamples 32-bit Color image `src` to `dst` with nearest-neighbor sampling
	void nativeResampleNearestNeighborColor(const NativeColorBuffer src, uint32_t srcWidth, uint32_t srcHeight, NativeColorBuffer dst, uint32_t dstWidth, uint32_t dstHeight);

	/// Resamples 8-bit monochrome image `src` to `dst` with a quick-estimation linear interpolation sampling
	void nativeResampleLerpFastLuma(const NativeLumaBuffer src, uint32_t srcWidth, uint32_t srcHeight, NativeLumaBuffer dst, uint32_t dstWidth, uint32_t dstHeight);

	/// Rotates an image by 180-degrees
	///
	/// This is an optimized method to flip the image horizontally and vertically in-place in a single pass
	void nativeRotate180(const NativeLumaBuffer src, uint32_t width, uint32_t height);

	// -----------------------------------------------------------------------------------------------------------------------------
	//  _                  ____            _     _             _   _
	// | |    ___   __ _  |  _ \ ___  __ _(_)___| |_ _ __ __ _| |_(_) ___  _ __
	// | |   / _ \ / _` | | |_) / _ \/ _` | / __| __| '__/ _` | __| |/ _ \| '_ \
	// | |__| (_) | (_| | |  _ <  __/ (_| | \__ \ |_| | | (_| | |_| | (_) | | | |
	// |_____\___/ \__, | |_| \_\___|\__, |_|___/\__|_|  \__,_|\__|_|\___/|_| |_|
	//             |___/             |___/
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Each of these methods registers a log receiver method. Receivers are set when registered. To unregister a log receiver,
	/// simply register with `nullptr`.
	void nativeLogRegisterDebug(NativeLogReceiver receiver);
	void nativeLogRegisterInfo(NativeLogReceiver receiver);
	void nativeLogRegisterWarn(NativeLogReceiver receiver);
	void nativeLogRegisterError(NativeLogReceiver receiver);
	void nativeLogRegisterSevere(NativeLogReceiver receiver);
	void nativeLogRegisterFatal(NativeLogReceiver receiver);
	void nativeLogRegisterTrace(NativeLogReceiver receiver);
	void nativeLogRegisterPerf(NativeLogReceiver receiver);
	void nativeLogRegisterStatus(NativeLogReceiver receiver);
	void nativeLogRegisterFrame(NativeLogReceiver receiver);
	void nativeLogRegisterSearch(NativeLogReceiver receiver);
	void nativeLogRegisterDecode(NativeLogReceiver receiver);
	void nativeLogRegisterResolve(NativeLogReceiver receiver);
	void nativeLogRegisterBadResolve(NativeLogReceiver receiver);
	void nativeLogRegisterCorrect(NativeLogReceiver receiver);
	void nativeLogRegisterIncorrect(NativeLogReceiver receiver);
	void nativeLogRegisterResult(NativeLogReceiver receiver);
	void nativeLogRegisterBadReport(NativeLogReceiver receiver);
	void nativeLogRegisterNetwork(NativeLogReceiver receiver);
	void nativeLogRegisterNetworkData(NativeLogReceiver receiver);
	void nativeLogRegisterVideo(NativeLogReceiver receiver);
	void nativeLogRegisterAlways(NativeLogReceiver receiver);

#if defined(__linux__)

	// -----------------------------------------------------------------------------------------------------------------------------
	// __     ___     _               ____            _                  
	// \ \   / (_) __| | ___  ___    / ___|__ _ _ __ | |_ _   _ _ __ ___ 
	//  \ \ / /| |/ _` |/ _ \/ _ \  | |   / _` | '_ \| __| | | | '__/ _ \
	//   \ V / | | (_| |  __/ (_) | | |__| (_| | |_) | |_| |_| | | |  __/
	//    \_/  |_|\__,_|\___|\___/   \____\__,_| .__/ \__|\__,_|_|  \___|
	//                                         |_|                       
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Causes video capturing from the camera to begin at the requested frame dimensions and rate
	///
	/// If `receiver` method is set, captured frames will be sent to that receiver. Otherwise, captured frames will rotate
	/// through a circular buffer where they can be polled. Use these methods to access that circular buffer of images:
	/// `nativeVideoCaptureImageLock()`, `nativeVideoCaptureImageUnlock()`, `nativeVideoCaptureImageGet()`,
	/// `nativeVideoCaptureImagePeek()`, `nativeVideoCaptureImageCount()`, `nativeVideoCaptureImageCapacity()`.
	///
	/// Returns error string or nullptr
	const char *nativeVideoCaptureStart(uint32_t frameWidth, uint32_t frameHeight, uint32_t frameRate, NativeCaptureFrameReceiver receiver);

	/// Causes video capture from the camera to stop
	///
	/// Returns error string or nullptr
	const char *nativeVideoCaptureStop();

	/// Locks the circular image buffer so it can be read safely in a threaded environment.
	///
	/// If you plan to keep this image for long, be sure to make a copy so you don't hold the lock too long.
	///
	/// This method will do nothing if `receiver` is set when calling `nativeVideoCaptureStart()`
	///
	/// Be sure to call `nativeVideoCaptureImageUnlock()` when you're finished with it.
	void nativeVideoCaptureImageLock();

	/// Unlocks the circular image buffer from a previous call to `nativeVideoCaptureImageLock()`.
	///
	/// This method will do nothing if `receiver` is set when calling `nativeVideoCaptureStart()`
	///
	/// See `nativeVideoCaptureImageLock()`
	void nativeVideoCaptureImageUnlock();

	/// Returns the next image (and increments the next pointer) from the circular buffer (or nullptr if none)
	///
	/// This method will always return nullptr if `receiver` is set when calling `nativeVideoCaptureStart()`
	///
	/// Be sure to wrap this call with `nativeVideoCaptureImageLock()` and `nativeVideoCaptureImageUnlock()` (see
	/// `nativeVideoCaptureImageLock()` for details.)
	NativeLumaBuffer nativeVideoCaptureImageGet();

	/// Returns the next image (without incrementing the next pointer) from the circular buffer (or nullptr if none)
	///
	/// This method will always return nullptr if `receiver` is set when calling `nativeVideoCaptureStart()`
	///
	/// Be sure to wrap this call with `nativeVideoCaptureImageLock()` and `nativeVideoCaptureImageUnlock()` (see
	/// `nativeVideoCaptureImageLock()` for details.)
	NativeLumaBuffer nativeVideoCaptureImagePeek();

	/// Returns the current number of images in the circular image buffer
	///
	/// This method will always return 0 if `receiver` is set when calling `nativeVideoCaptureStart()`
	///
	/// To see the capacity of the circular image buffer, see `nativeVideoCaptureImageCapacity()`
	int32_t nativeVideoCaptureImageCount();

	/// Returns the total capacity of the circular image buffer
	///
	/// This method will always return 0 if `receiver` is set when calling `nativeVideoCaptureStart()`
	///
	/// For the number of images in the circular image buffer, see `nativeVideoCaptureImageCount()`
	int32_t nativeVideoCaptureImageCapacity();

#endif // defined(__linux__)

#ifdef __cplusplus
}
#endif //__cplusplus
