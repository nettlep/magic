//
//  VcosException.h
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

extern "C"
{
	#include "interface/mmal/mmal.h"
}

#include "VideoException.h"

/// Specialization of the VideoException for MMAL video capture errors
struct VcosException : public VideoException
{
	/// Construct a VcosException with a C-style string message
	///
	/// Also available: construction via std::string and std::ostream (via std::stringstream)
	public: VcosException(MMAL_STATUS_T status, const char *message)
	: VideoException(message), mStatus(status)
	{
	}

	/// Construct a VcosException with a std::string message
	///
	/// Also available: construction via C-style string and std::ostream (via std::stringstream)
	public: VcosException(MMAL_STATUS_T status, const std::string &message)
	: VideoException(message), mStatus(status)
	{
	}

	/// Construct a VcosException with a std::ostream (via std::stringstream)
	/// 
	/// The convention for using this includes the use of the `SSTR` typedef, which works as follows:
	///
	///		throw VcosException(MMAL_SUCCESS, SSTR << "Decoding complete. " << frameCount << " frames decoded in " << perf.ms << "ms.");
	/// 
	/// Also available: construction via C-style strings and std::string
	public: VcosException(MMAL_STATUS_T status, const std::ostream &message)
	: VideoException(message), mStatus(status)
	{
	}

	/// Converts a MMAL_STATUS_T value to a human-readable string
	public: static std::string statusMessage(MMAL_STATUS_T status)
	{
		switch (status)
		{
			case MMAL_SUCCESS:   return std::string("MMAL: Success");
			case MMAL_ENOMEM:    return std::string("MMAL: Out of memory");
			case MMAL_ENOSPC:    return std::string("MMAL: Out of resources (other than memory)");
			case MMAL_EINVAL:    return std::string("MMAL: Argument is invalid");
			case MMAL_ENOSYS:    return std::string("MMAL: Function not implemented");
			case MMAL_ENOENT:    return std::string("MMAL: No such file or directory");
			case MMAL_ENXIO:     return std::string("MMAL: No such device or address");
			case MMAL_EIO:       return std::string("MMAL: I/O error");
			case MMAL_ESPIPE:    return std::string("MMAL: Illegal seek");
			case MMAL_ECORRUPT:  return std::string("MMAL: Data is corrupt (not POSIX)");
			case MMAL_ENOTREADY: return std::string("MMAL: Component is not ready (not POSIX)");
			case MMAL_ECONFIG:   return std::string("MMAL: Component is not configured (not POSIX)");
			case MMAL_EISCONN:   return std::string("MMAL: Port is already connected ");
			case MMAL_ENOTCONN:  return std::string("MMAL: Port is disconnected");
			case MMAL_EAGAIN:    return std::string("MMAL: Resource temporarily unavailable; try again later");
			case MMAL_EFAULT:    return std::string("MMAL: Bad address");
			default:             return std::string("MMAL: Unknown status");
		}
	}

	/// Returns explanatory information
	///
	/// Guaranteed to be a valid pointer
	public: virtual const char* what() const noexcept
	{
		return (VcosException::statusMessage(mStatus) + " -- " + mMessage).c_str();
	}

	/// Our MMAL status related to this exception
	private: MMAL_STATUS_T mStatus;
};

#endif // defined(USE_MMAL)
