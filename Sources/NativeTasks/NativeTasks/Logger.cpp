//
//  Logger.cpp
//  NativeTasks
//
//  Created by Paul Nettle on 5/22/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#include "Logger.h"

NativeLogReceiver Logger::logReceiverDebug = nullptr;
NativeLogReceiver Logger::logReceiverInfo = nullptr;
NativeLogReceiver Logger::logReceiverWarn = nullptr;
NativeLogReceiver Logger::logReceiverError = nullptr;
NativeLogReceiver Logger::logReceiverSevere = nullptr;
NativeLogReceiver Logger::logReceiverFatal = nullptr;
NativeLogReceiver Logger::logReceiverTrace = nullptr;
NativeLogReceiver Logger::logReceiverPerf = nullptr;
NativeLogReceiver Logger::logReceiverStatus = nullptr;
NativeLogReceiver Logger::logReceiverFrame = nullptr;
NativeLogReceiver Logger::logReceiverSearch = nullptr;
NativeLogReceiver Logger::logReceiverDecode = nullptr;
NativeLogReceiver Logger::logReceiverResolve = nullptr;
NativeLogReceiver Logger::logReceiverCorrect = nullptr;
NativeLogReceiver Logger::logReceiverIncorrect = nullptr;
NativeLogReceiver Logger::logReceiverResult = nullptr;
NativeLogReceiver Logger::logReceiverBadReport = nullptr;
NativeLogReceiver Logger::logReceiverNetwork = nullptr;
NativeLogReceiver Logger::logReceiverNetworkData = nullptr;
NativeLogReceiver Logger::logReceiverVideo = nullptr;
NativeLogReceiver Logger::logReceiverAlways = nullptr;
