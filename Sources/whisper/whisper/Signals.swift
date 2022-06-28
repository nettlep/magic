//
//  Signals.swift
//  Whisper
//
//  Created by Paul Nettle on 4/2/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#if os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

internal enum Signal: Int32
{
	case HUP    = 1
	case INT    = 2
	case QUIT   = 3
	case ILL    = 4
	case TRAP   = 5
	case ABRT   = 6
	case EMT    = 7
	case FPE    = 8
	case KILL   = 9
	case BUS    = 10
	case SEGV   = 11
	case SYS    = 12
	case PIPE   = 13
	case ALRM   = 14
	case TERM   = 15
	case URG    = 16
	case STOP   = 17
	case TSTP   = 18
	case CONT   = 19
	case CHLD   = 20
	case TTIN   = 21
	case TTOU   = 22
	case IO     = 23
	case XCPU   = 24
	case XFSZ   = 25
	case VTALRM = 26
	case PROF   = 27
	case WINCH  = 28
	case INFO   = 29
	case USR1   = 30
	case USR2   = 31
}

typealias SigactionHandler = @convention(c)(Int32) -> Void

internal func trap(signum: Signal, action: @escaping SigactionHandler)
{
#if os(Linux)
	var sigAction = sigaction()
	sigAction.__sigaction_handler = unsafeBitCast(action, to: sigaction.__Unnamed_union___sigaction_handler.self)
	sigaction(signum.rawValue, &sigAction, nil)
#elseif os(macOS)
	// From Swift, sigaction.init() collides with the Darwin.sigaction() function.
	// This local typealias allows us to disambiguate them.
	typealias SignalAction = sigaction

	var signalAction = SignalAction(__sigaction_u: unsafeBitCast(action, to: __sigaction_u.self), sa_mask: 0, sa_flags: 0)

	withUnsafePointer(to: &signalAction)
	{ actionPointer -> Void in
		sigaction(signum.rawValue, actionPointer, nil)
	}
#endif
}
