//
//  WhisperServerPeer.swift
//  Whisper
//
//  Created by Paul Nettle on 2/23/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import Minion
import Seer

/// Our application-specific `ServerPeer` implementation, handling payloads specific to Whisper
public class WhisperServerPeer: SeerServerPeer
{
	/// A factory for creating `WhisperServerPeer` instances
	///
	/// This is used when starting an instance of `Server` (via `Server`'s `start` method)
	public static func createWhisperServerPeer(socketAddress: Ipv4SocketAddress, server: Server) -> WhisperServerPeer?
	{
		return WhisperServerPeer(socketAddress: socketAddress, server: server)
	}

	/// Custom code to send information to clients when they connect
	public override func onServerConnect(from socketAddress: Ipv4SocketAddress)
	{
		super.onServerConnect(from: socketAddress)

		guard let socket = self.socket else
		{
			gLogger.error("WhisperServerPeer.onServerConnect: Server connection received ping, but does not appear to be connected (no socket)")
			return
		}

		let connMessage = ServerConnectMessage(versions: ["Whisper": whisperVersion, "Minion": MinionVersion, "Seer": SeerVersion])
		if !(connMessage.getPayload()?.send(to: socketAddress, over: socket) ?? false)
		{
			gLogger.warn("WhisperServerPeer.onServerConnect: Failed to send ServerConnect message")
		}
	}

	/// Provides access to the active `MediaProvider`
	public override func getMediaProvider() -> MediaProvider?
	{
		return Whisper.instance.mediaProvider
	}

	public override func onSystemShutdown()
	{
		Whisper.systemShutdown()
	}

	public override func onSystemReboot()
	{
		Whisper.systemReboot()
	}

	public override func onCheckForUpdates()
	{
		Whisper.checkForUpdates()
	}
}
