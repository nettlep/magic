//
//  CircularImageBuffer.h
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
#include <assert.h>
#include "Mutex.h"
#include "include/NativeTaskTypes.h"

template<class SampleType>
class CircularImageBuffer
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Local types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Type used to define a Circular buffer
	private: typedef std::vector<SampleType *> CircularBufferType;

	/// Type used to define a size specifier for the number of entries in a CircularBuffer
	private: typedef typename CircularBufferType::size_type CircularBufferSizeType;

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the total number of frames we've added to the buffer
	///
	/// To reset stats, see `resetStats()`
	public: unsigned int statFramesAdded() const { return mStatFramesAdded; }

	/// Returns the total number of frames we've read from the buffer
	///
	/// To reset stats, see `resetStats()`
	public: unsigned int statFramesRead() const { return mStatFramesRead; }

	/// Returns the total number of frames we've lost (we fell behind)
	///
	/// To reset stats, see `resetStats()`
	public: unsigned int statFramesSkipped() const { return mStatFramesSkipped; }

	/// Returns the total number of images in the buffer
	public: int count() const { return mCount; }

	/// Returns the capacity of the buffer
	///
	/// This represents the total number of images the buffer can (but doesn't necessarily) contain
	public: int capacity() const { return static_cast<int>(mCircularBuffer.capacity()); }

	/// Returns the width of the images storeed in the buffer
	public: unsigned int width() const { return mWidth; }

	/// Returns the height of the images storeed in the buffer
	public: unsigned int height() const { return mHeight; }

	/// Returns true if the buffer is empty, otherwise false
	public: bool isEmpty() const { return mCount == 0; }

	/// Returns true if the buffer is full (i.e., the next add will overwrite the oldest entry not yet read
	public: bool isFull() const { return mCount == capacity(); }

	/// Lock the internal mutex to enable thread safe access
	///
	/// This is generally required for access to the get/peek methods
	public: void lock() const { mMutex.lock(); }

	/// Lock the internal mutex to enable thread safe access
	///
	/// This is generally required for access to the get/peek methods
	public: void unlock() const { mMutex.unlock(); }

	// -----------------------------------------------------------------------------------------------------------------------------
	// Construction
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialization and deinitialization
	public: CircularImageBuffer(unsigned int width, unsigned int height, CircularBufferSizeType capacity = 3)
	{
		// Setup our dimensions
		mWidth = width;
		mHeight = height;

		// Preallocate the images in our circular buffer
		mCircularBuffer.reserve(capacity);

		for (CircularBufferSizeType i = 0; i < capacity; ++i)
		{
			SampleType *newImage = new SampleType[width * height];
			mCircularBuffer.push_back(newImage);
		}

		// Ensure we're at a valid starting point
		reset();
		resetStats();
	}

	/// Destruct and free all resources
	public: ~CircularImageBuffer()
	{
		// Free up our allocated images
		for (CircularBufferSizeType i = 0; i < mCircularBuffer.size(); ++i)
		{
			delete[] mCircularBuffer[i];
		}
		mCircularBuffer.clear();
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Buffer management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Add an image to the circular buffe by copying the image into the next (least recently used) slot.
	///
	/// The add operation always succeeds. However, an add operation could potentially overwrite an existing
	/// image. To determine if this will happen, compare capacity() with count() before calling this method.
	/// If they are equal, then an overwrite will occur.
	///
	/// This method requires that an empty circular buffer has been fully reset and not simply left in the
	/// previous state (i.e., if mCount == 0, then mNextAddIndex must be 0 and mNextGetIndex must be -1).
	public: void add(SampleType *image)
	{
		mMutex.lock();

		// We need a capacity
		assert(capacity() > 0);

		// Do nothing if we have no capacity
		if (capacity() == 0) { return; }

		// Ensure our counts and indices agree to our empty/not-empty state
		if (isEmpty())
		{
			assert(count() == 0);
			assert(mNextAddIndex == 0);
			assert(mNextGetIndex == -1);
			assert(!isFull());
		}
		else
		{
			// Sanity check: Full state means an overwrite is pending, non-full state means no overwrite pending
			assert(isFull() == (mNextAddIndex == mNextGetIndex));
			assert(count() > 0);
			assert(count() <= capacity());
			assert(mNextAddIndex >= 0);
			assert(mNextAddIndex < capacity());
			assert(mNextGetIndex >= 0);
			assert(mNextGetIndex < capacity());
		}

		// Copy the image into the next add index
		memcpy(mCircularBuffer[mNextAddIndex], image, width() * height() * sizeof(SampleType));

		// Track the newly added frame
		mStatFramesAdded++;

		// If we're full, we've just overwrote a frame
		if (isFull())
		{
			// Increment our next add index
			mNextAddIndex = (mNextAddIndex + 1) % capacity();

			// Increment our next get index
			mNextGetIndex = (mNextGetIndex + 1) % capacity();

			// Track those that were skipped
			mStatFramesSkipped += 1;
		}
		// Not full, track the add like normal
		else
		{
			// If we're empty, point our get index at the new entry
			if (isEmpty()) mNextGetIndex = mNextAddIndex;
			assert(mNextGetIndex >= 0);
			assert(mNextGetIndex < capacity());

			// Increment our count
			mCount += 1;

			// Sanity check our count against our capacity
			assert(count() <= capacity());

			// Increment our next add index
			mNextAddIndex = (mNextAddIndex + 1) % capacity();
		}

		mMutex.unlock();
	}

	/// This method needs to reset() when the count drops to 0
	///
	/// In order to be thread safe, you must wrap calls to this method with lock() and unlock().
	/// If you intend to hold the data for long, copy it to a buffer in order to release the lock.
	///
	/// Returns the image pointer, or nullptr if the buffer is empty (see isEmpty()).
	public: SampleType *get()
	{
		if (isEmpty()) return nullptr;

		// Grab the image - this is what we'll return
		SampleType *image = mCircularBuffer[mNextGetIndex];

		// Track our stats
		mStatFramesRead += 1;

		// Update the count
		mCount -= 1;
		assert(count() >= 0);

		// If we're empty, reset the buffer
		if (isEmpty())
		{
			reset();
		}
		// Not empty, move to the next get position
		else
		{
			// Increment our next get index
			mNextGetIndex = (mNextGetIndex + 1) % capacity();
			assert(mNextGetIndex >= 0);
			assert(mNextGetIndex < capacity());
		}

		// Here ya go!
		return image;
	}

	/// Returns the next buffer without modifying the state of the buffers
	///
	/// In order to be thread safe, you must wrap calls to this method with lock() and unlock().
	/// If you intend to hold the data for long, copy it to a buffer in order to release the lock.
	public: SampleType *peek() const
	{
		if (isEmpty()) return nullptr;
		return mCircularBuffer[mNextGetIndex];
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Reset the circular buffer to an empty state.
	///
	/// This method does not remove the allocated capacity, but rather resets the state indices to values
	/// that represent an empty buffer.
	///
	/// NOTE: This method does not reset statistics. For that, see `resetStats()`.
	public: void reset()
	{
		mMutex.lock();
		mCount = 0;
		mNextAddIndex = 0;
		mNextGetIndex = -1;
		mMutex.unlock();
	}

	/// Reset our tracked statistics
	public: void resetStats()
	{
		mMutex.lock();
		mStatFramesAdded = 0;
		mStatFramesRead = 0;
		mStatFramesSkipped = 0;
		mMutex.unlock();
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Data members
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The image dimension (width)
	private: unsigned int mWidth;

	/// The image dimension (height)
	private: unsigned int mHeight;

	/// Tracks the total number of frames we've added to the buffer
	private: unsigned int mStatFramesAdded;

	/// Tracks the total number of frames we've read from the buffer
	private: unsigned int mStatFramesRead;

	/// Tracks the total number of frames we've lost (we fell behind)
	private: unsigned int mStatFramesSkipped;

	/// Storage for our buffer of images
	private: CircularBufferType mCircularBuffer;

	/// Returns the total number of images in the buffer
	private: int mCount;

	/// The next image to be added to the buffer will go into this index
	private: int mNextAddIndex;

	/// The next image to be pulled from the buffer will come from this index
	///
	/// Note that this value can be -1 if there are no images in the buffer
	private: int mNextGetIndex;

	/// Our mutex for thread safety
	///
	/// LIMITATION: There is only one of these for all CircularImageBuffer objects
	private: static Mutex mMutex;
};

/// Our single mutex for the circular image buffer
template<class SampleType> Mutex CircularImageBuffer<SampleType>::mMutex = Mutex("CircularImageBuffer");

#endif // defined(USE_MMAL)
