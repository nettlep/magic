//
//  NativeTaskTypes.h
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

#include <stdint.h>

/// Type used to represent an 8-bit Luma image sample
typedef uint8_t LumaSample;

/// Type used to represent an 8-bit Luma image buffer
typedef LumaSample * NativeLumaBuffer;

/// Type used to represent an 8-bit Luma image sample
typedef uint32_t ColorSample;

/// Type used to represent an 8-bit Luma image buffer
typedef ColorSample * NativeColorBuffer;

/// This little ditty is to simplify the use of stringstream being passed into the logging methods. This allows us to do something
/// similar to the following:
///
///    Logger::info(SSTR << "There were " << count << " entries in the list");
#define SSTR std::ostringstream().flush()

// ---------------------------------------------------------------------------------------------------------------------------------
//  ____               _                    
// |  _ \ ___  ___ ___(_)_   _____ _ __ ___ 
// | |_) / _ \/ __/ _ \ \ \ / / _ \ '__/ __|
// |  _ <  __/ (_|  __/ |\ V /  __/ |  \__ \
// |_| \_\___|\___\___|_| \_/ \___|_|  |___/
//                                          
// ---------------------------------------------------------------------------------------------------------------------------------

/// Type definition for a callback that receives images from NativeTasks
typedef void (* NativeCaptureFrameReceiver)(LumaSample *sampleData, uint32_t width, uint32_t height);

/// Type definition for a callback that receives log messages
typedef void (* NativeLogReceiver)(const char *message);
