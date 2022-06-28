//
//  Logger.h
//  NativeTasks
//
//  Created by Paul Nettle on 5/22/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#include <string>
#include <sstream>
#include "include/NativeInterface.h"
#include "include/NativeTaskTypes.h"

/// This class provides a pass-through logging mechanism to the registered logging receivers
class Logger
{

	/// Register logging receivers.
	///
	/// To unregister, simply call with `nullptr`
	public: static void registerDebugReceiver(NativeLogReceiver receiver) { logReceiverDebug = receiver; }
	public: static void registerInfoReceiver(NativeLogReceiver receiver) { logReceiverInfo = receiver; }
	public: static void registerWarnReceiver(NativeLogReceiver receiver) { logReceiverWarn = receiver; }
	public: static void registerErrorReceiver(NativeLogReceiver receiver) { logReceiverError = receiver; }
	public: static void registerSevereReceiver(NativeLogReceiver receiver) { logReceiverSevere = receiver; }
	public: static void registerFatalReceiver(NativeLogReceiver receiver) { logReceiverFatal = receiver; }
	public: static void registerTraceReceiver(NativeLogReceiver receiver) { logReceiverTrace = receiver; }
	public: static void registerPerfReceiver(NativeLogReceiver receiver) { logReceiverPerf = receiver; }
	public: static void registerStatusReceiver(NativeLogReceiver receiver) { logReceiverStatus = receiver; }
	public: static void registerFrameReceiver(NativeLogReceiver receiver) { logReceiverFrame = receiver; }
	public: static void registerSearchReceiver(NativeLogReceiver receiver) { logReceiverSearch = receiver; }
	public: static void registerDecodeReceiver(NativeLogReceiver receiver) { logReceiverDecode = receiver; }
	public: static void registerResolveReceiver(NativeLogReceiver receiver) { logReceiverResolve = receiver; }
	public: static void registerCorrectReceiver(NativeLogReceiver receiver) { logReceiverCorrect = receiver; }
	public: static void registerIncorrectReceiver(NativeLogReceiver receiver) { logReceiverIncorrect = receiver; }
	public: static void registerResultReceiver(NativeLogReceiver receiver) { logReceiverResult = receiver; }
	public: static void registerBadReportReceiver(NativeLogReceiver receiver) { logReceiverBadReport = receiver; }
	public: static void registerNetworkReceiver(NativeLogReceiver receiver) { logReceiverNetwork = receiver; }
	public: static void registerNetworkDataReceiver(NativeLogReceiver receiver) { logReceiverNetworkData = receiver; }
	public: static void registerVideoReceiver(NativeLogReceiver receiver) { logReceiverVideo = receiver; }
	public: static void registerAlwaysReceiver(NativeLogReceiver receiver) { logReceiverAlways = receiver; }

	/// These methods simply pass through the messages to the callback method, if present
	public: static void debug(const char *text) { if (nullptr != logReceiverDebug) { logReceiverDebug(text); } }
	public: static void debug(const std::string &text) { if (nullptr != logReceiverDebug) { debug(text.c_str()); } }
	public: static void debug(const std::ostream &text) { if (nullptr != logReceiverDebug) { debug(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void info(const char *text) { if (nullptr != logReceiverInfo) { logReceiverInfo(text); } }
	public: static void info(const std::string &text) { if (nullptr != logReceiverInfo) { info(text.c_str()); } }
	public: static void info(const std::ostream &text) { if (nullptr != logReceiverInfo) { info(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void warn(const char *text) { if (nullptr != logReceiverWarn) { logReceiverWarn(text); } }
	public: static void warn(const std::string &text) { if (nullptr != logReceiverWarn) { warn(text.c_str()); } }
	public: static void warn(const std::ostream &text) { if (nullptr != logReceiverWarn) { warn(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void error(const char *text) { if (nullptr != logReceiverError) { logReceiverError(text); } }
	public: static void error(const std::string &text) { if (nullptr != logReceiverError) { error(text.c_str()); } }
	public: static void error(const std::ostream &text) { if (nullptr != logReceiverError) { error(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void severe(const char *text) { if (nullptr != logReceiverSevere) { logReceiverSevere(text); } }
	public: static void severe(const std::string &text) { if (nullptr != logReceiverSevere) { severe(text.c_str()); } }
	public: static void severe(const std::ostream &text) { if (nullptr != logReceiverSevere) { severe(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void fatal(const char *text) { if (nullptr != logReceiverFatal) { logReceiverFatal(text); } }
	public: static void fatal(const std::string &text) { if (nullptr != logReceiverFatal) { fatal(text.c_str()); } }
	public: static void fatal(const std::ostream &text) { if (nullptr != logReceiverFatal) { fatal(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void trace(const char *text) { if (nullptr != logReceiverTrace) { logReceiverTrace(text); } }
	public: static void trace(const std::string &text) { if (nullptr != logReceiverTrace) { trace(text.c_str()); } }
	public: static void trace(const std::ostream &text) { if (nullptr != logReceiverTrace) { trace(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void perf(const char *text) { if (nullptr != logReceiverPerf) { logReceiverPerf(text); } }
	public: static void perf(const std::string &text) { if (nullptr != logReceiverPerf) { perf(text.c_str()); } }
	public: static void perf(const std::ostream &text) { if (nullptr != logReceiverPerf) { perf(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void status(const char *text) { if (nullptr != logReceiverStatus) { logReceiverStatus(text); } }
	public: static void status(const std::string &text) { if (nullptr != logReceiverStatus) { status(text.c_str()); } }
	public: static void status(const std::ostream &text) { if (nullptr != logReceiverStatus) { status(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void frame(const char *text) { if (nullptr != logReceiverFrame) { logReceiverFrame(text); } }
	public: static void frame(const std::string &text) { if (nullptr != logReceiverFrame) { frame(text.c_str()); } }
	public: static void frame(const std::ostream &text) { if (nullptr != logReceiverFrame) { frame(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void search(const char *text) { if (nullptr != logReceiverSearch) { logReceiverSearch(text); } }
	public: static void search(const std::string &text) { if (nullptr != logReceiverSearch) { search(text.c_str()); } }
	public: static void search(const std::ostream &text) { if (nullptr != logReceiverSearch) { search(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void decode(const char *text) { if (nullptr != logReceiverDecode) { logReceiverDecode(text); } }
	public: static void decode(const std::string &text) { if (nullptr != logReceiverDecode) { decode(text.c_str()); } }
	public: static void decode(const std::ostream &text) { if (nullptr != logReceiverDecode) { decode(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void resolve(const char *text) { if (nullptr != logReceiverResolve) { logReceiverResolve(text); } }
	public: static void resolve(const std::string &text) { if (nullptr != logReceiverResolve) { resolve(text.c_str()); } }
	public: static void resolve(const std::ostream &text) { if (nullptr != logReceiverResolve) { resolve(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void badResolve(const char *text) { if (nullptr != logReceiverBadResolve) { logReceiverBadResolve(text); } }
	public: static void badResolve(const std::string &text) { if (nullptr !=  logReceiverBadResolve) { badResolve(text.c_str()); } }
	public: static void badResolve(const std::ostream &text) { if (nullptr != logReceiverBadResolve) { badResolve(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void correct(const char *text) { if (nullptr != logReceiverCorrect) { logReceiverCorrect(text); } }
	public: static void correct(const std::string &text) { if (nullptr != logReceiverCorrect) { correct(text.c_str()); } }
	public: static void correct(const std::ostream &text) { if (nullptr != logReceiverCorrect) { correct(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void incorrect(const char *text) { if (nullptr != logReceiverIncorrect) { logReceiverIncorrect(text); } }
	public: static void incorrect(const std::string &text) { if (nullptr != logReceiverIncorrect) { incorrect(text.c_str()); } }
	public: static void incorrect(const std::ostream &text) { if (nullptr != logReceiverIncorrect) { incorrect(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void result(const char *text) { if (nullptr != logReceiverResult) { logReceiverResult(text); } }
	public: static void result(const std::string &text) { if (nullptr != logReceiverResult) { result(text.c_str()); } }
	public: static void result(const std::ostream &text) { if (nullptr != logReceiverResult) { result(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void badReport(const char *text) { if (nullptr != logReceiverBadReport) { logReceiverBadReport(text); } }
	public: static void badReport(const std::string &text) { if (nullptr != logReceiverBadReport) { badReport(text.c_str()); } }
	public: static void badReport(const std::ostream &text) { if (nullptr != logReceiverBadReport) { badReport(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void network(const char *text) { if (nullptr != logReceiverNetwork) { logReceiverNetwork(text); } }
	public: static void network(const std::string &text) { if (nullptr != logReceiverNetwork) { network(text.c_str()); } }
	public: static void network(const std::ostream &text) { if (nullptr != logReceiverNetwork) { network(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void networkData(const char *text) { if (nullptr != logReceiverNetworkData) { logReceiverNetworkData(text); } }
	public: static void networkData(const std::string &text) { if (nullptr != logReceiverNetworkData) { networkData(text.c_str()); } }
	public: static void networkData(const std::ostream &text) { if (nullptr != logReceiverNetworkData) { networkData(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void video(const char *text) { if (nullptr != logReceiverVideo) { logReceiverVideo(text); } }
	public: static void video(const std::string &text) { if (nullptr != logReceiverVideo) { video(text.c_str()); } }
	public: static void video(const std::ostream &text) { if (nullptr != logReceiverVideo) { video(static_cast<const std::ostringstream&>(text).str().c_str()); } }
	public: static void always(const char *text) { if (nullptr != logReceiverAlways) { logReceiverAlways(text); } }
	public: static void always(const std::string &text) { if (nullptr != logReceiverAlways) { always(text.c_str()); } }
	public: static void always(const std::ostream &text) { if (nullptr != logReceiverAlways) { always(static_cast<const std::ostringstream&>(text).str().c_str()); } }

	/// The registered logging receivers
	private: static NativeLogReceiver logReceiverDebug;
	private: static NativeLogReceiver logReceiverInfo;
	private: static NativeLogReceiver logReceiverWarn;
	private: static NativeLogReceiver logReceiverError;
	private: static NativeLogReceiver logReceiverSevere;
	private: static NativeLogReceiver logReceiverFatal;
	private: static NativeLogReceiver logReceiverTrace;
	private: static NativeLogReceiver logReceiverPerf;
	private: static NativeLogReceiver logReceiverStatus;
	private: static NativeLogReceiver logReceiverFrame;
	private: static NativeLogReceiver logReceiverSearch;
	private: static NativeLogReceiver logReceiverDecode;
	private: static NativeLogReceiver logReceiverResolve;
	private: static NativeLogReceiver logReceiverBadResolve;
	private: static NativeLogReceiver logReceiverCorrect;
	private: static NativeLogReceiver logReceiverIncorrect;
	private: static NativeLogReceiver logReceiverResult;
	private: static NativeLogReceiver logReceiverBadReport;
	private: static NativeLogReceiver logReceiverNetwork;
	private: static NativeLogReceiver logReceiverNetworkData;
	private: static NativeLogReceiver logReceiverVideo;
	private: static NativeLogReceiver logReceiverAlways;
};
