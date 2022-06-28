//
//  VideoException.h
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

#include <string>
#include <sstream>
#include "include/NativeTaskTypes.h"

/// Manages general video-related exceptions
///
/// For specific types of video exceptions (for example, those from camera captures) this method should be subclassed.
struct VideoException : public std::exception
{
	/// Construct a VideoException with a C-style string message
	///
	/// Also available: construction via std::string and std::ostream (via std::stringstream)
	public: VideoException(const char *message) : mMessage(nullptr == message ? "- unspecified -" : message) { }

	/// Construct a VideoException with a std::string message
	///
	/// Also available: construction via C-style string and std::ostream (via std::stringstream)
	public: VideoException(const std::string &message) : mMessage(message) { }

	/// Construct a VideoException with a std::ostream (via std::stringstream)
	/// 
	/// The convention for using this includes the use of the `SSTR` typedef, which works as follows:
	///
	///		throw VideoException(SSTR << "Decoding complete. " << frameCount << " frames decoded in " << perf.ms << "ms.");
	/// 
	/// Also available: construction via C-style strings and std::string
	public: VideoException(const std::ostream &message) : mMessage(static_cast<const std::ostringstream&>(message).str()) { }

	/// We'll need a virtual destructor so we can override
	public: virtual ~VideoException() { }

	/// Returns explanatory information
	///
	/// Guaranteed to be a valid pointer.
	public: virtual const char* what() const noexcept { return mMessage.c_str(); }

	/// Our stored message
	protected: std::string mMessage;
};

#endif // defined(USE_MMAL)
