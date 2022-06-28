//
//  SecDescriptor.h
//  NativeTasks
//
//  Created by Paul Nettle on 5/25/19.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#pragma once

#if defined(__linux__)

/// Returns a string with the permanent ethernet MAC addresses
const char *secDescriptor(const char *name);

#endif // defined(__linux__)
