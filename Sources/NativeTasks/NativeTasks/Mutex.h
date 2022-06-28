//
//  Mutex.h
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

extern "C"
{
	#include <interface/vcos/vcos_mutex.h>
}

/// Class that represents a mutex
///
/// Usage:
///
///		1. Construct the class (ideally as a static object)
///		2. Check the isValid() flag (must be true)
///		3. Call lock()
///		4. Perform your thread-safe operations
///		5. Call unlock()
class Mutex
{	
	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The status of the mutex
	///
	/// After construction, this must be true or the mutex will do nothing
	public: bool isValid() const { return mValid; }
	private: bool mValid;

	/// This is our mutex
	private: VCOS_MUTEX_T mMutex;

	// -----------------------------------------------------------------------------------------------------------------------------
	// Construction
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize the mutex with a given name
	public: Mutex(const char *mutexName)
	{
		VCOS_STATUS_T vst = vcos_mutex_create(&mMutex, mutexName);
		mValid = vst == VCOS_SUCCESS;

		// Sanity check
		assert(isValid());
	}

	/// Destruct the mutex, releasing it
	public: ~Mutex()
	{
		if (isValid())
		{
			vcos_mutex_delete(&mMutex);
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Mutex control
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Locks the mutex
	///
	/// Call this before code that needs to run thread-safe
	public: void lock()
	{
		assert(isValid());
		if (isValid())
		{
			vcos_mutex_lock(&mMutex);
		}
	}

	/// Unlock the mutex
	///
	/// Call this after code that needs to run thread-safe
	public: void unlock()
	{
		assert(isValid());
		if (isValid())
		{
			vcos_mutex_unlock(&mMutex);
		}
	}
};

#endif // defined(USE_MMAL)
