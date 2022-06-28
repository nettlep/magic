//
//  AbraServerPeer.swift
//  Abra
//
//  Created by Paul Nettle on 2/23/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
#if os(iOS)
import SeerIOS
import MinionIOS
#else
import Seer
import Minion
#endif

/// Our application-specific `ServerPeer` implementation, handling payloads specific to Steve
///
/// This class is responsible for handling all server-related operations, such as handling connections and disconnections,
/// responding to pings and payloads and so on.
///
/// This base implementation should serve as a starting point, but a minimum set of actions are required by the subclass
/// implementation. For example, it is likely that the subclass implementation will need to create a custom factory method
/// (ex: `createMyServerPeer`, similar to `createServerPeer`) which is used when instantiating a `MediaConsumer`.
///
/// In addition, it is expected that the subclass implementation will override `onServerConnect` and provide a minimum custom
/// implementation that sends a `ServerConnectMessage`.
///
/// All subclass implementations should be sure to call the `super` implementation unless they have a good reason not to.
public class AbraServerPeer: SeerServerPeer
{
	/// A factory for creating `AbraServerPeer` instances
	///
	/// This is used when starting an instance of `Server` (via `Server`'s `start` method)
	public static func createAbraServerPeer(socketAddress: Ipv4SocketAddress, server: Server) -> AbraServerPeer?
	{
		gLogger.network("AbraServerPeer.createAbraServerPeer: Creating server peer for \(socketAddress.description)")
		return AbraServerPeer(socketAddress: socketAddress, server: server)
	}

	/// Custom code to send information to clients when they connect
	public override func onServerConnect(from socketAddress: Ipv4SocketAddress)
	{
		super.onServerConnect(from: socketAddress)

		guard let socket = self.socket else
		{
			gLogger.error("AbraServerPeer.onServerConnect: Server connection received but does not appear to be connected (no socket)")
			return
		}

		let connMessage = ServerConnectMessage(versions: ["Abra": AbraVersion, "Minion": MinionVersion, "Seer": SeerVersion])
		if !(connMessage.getPayload()?.send(to: socketAddress, over: socket) ?? false)
		{
			gLogger.warn("AbraServerPeer.onServerConnect: Failed to send ServerConnect message")
		}
	}

	/// Provides access to the active `MediaProvider`
	public override func getMediaProvider() -> MediaProvider?
	{
		return AbraCaptureMediaProvider.shared
	}
}
