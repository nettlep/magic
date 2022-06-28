//
//  SeerServerPeer.swift
//  Seer
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
import MinionIOS
#else
import Minion
#endif
import Dispatch

/// A Server Peer's base implementation. Server implementations are expected to subclass this object and extend the implementation.
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
open class SeerServerPeer: Peer
{
	/// The local server
	private let server: Server

	/// The config change notification ID we received when we added the notification receiver
	private var configChangeNotificationId: Int = -1

	/// A factory for creating generic `ServerPeer` instances
	///
	/// This is used when starting an instance of `Server` (via `Server`'s `start` method)
	public static func createServerPeer(socketAddress: Ipv4SocketAddress, server: Server) -> SeerServerPeer?
	{
		return SeerServerPeer(socketAddress: socketAddress, server: server)
	}

	/// Initialize a `SeerServerPeer` from its base components
	public init?(socketAddress: Ipv4SocketAddress, server: Server)
	{
		self.server = server
		super.init(socketAddress: socketAddress)

		// Add a config change notification
		self.configChangeNotificationId = Config.addValueChangeNotificationReceiver { self.onConfigValueChanged($0) }
	}

	deinit
	{
		// Remove our config change notification
		if configChangeNotificationId != 0
		{
			_ = Config.removeValueChangeNotificationReceiver(id: configChangeNotificationId)
		}
	}

	/// Called when a config value is changed
	private func onConfigValueChanged(_ name: String?)
	{
		if let name = name
		{
			guard let message = Config.getConfigValueMessage(name: name) else
			{
				gLogger.error("SeerServerPeer.onConfigValueChanged: Unable to get config value for '\(name)'")
				return
			}

			if let payload = message.getPayload()
			{
				server.send(payload: payload)
			}
		}
		else
		{
			sendConfigValueList()
		}
	}

	/// Manage server connections of the peer at `socketAddress`.
	///
	/// The base implementation will add the new peer to the server and respond with an `AdvertiseAckMessage`.
	override open func onServerConnect(from socketAddress: Ipv4SocketAddress)
	{
		super.onServerConnect(from: socketAddress)

		// Add the new peer
		guard let peer = server.addPeer(socketAddress: socketAddress) else
		{
			gLogger.error("ServerPeer.onServerConnect: Unable to add new peer: \(socketAddress)")
			return
		}

		gLogger.network("ServerPeer.onServerConnect: Peer added (fd = \(peer.socket == nil ? "[nil]":"\(peer.socket!.fd)")): \(socketAddress)")

		guard let controlPort = server.controlPort else
		{
			gLogger.error("ServerPeer.onServerConnect: Server has no control port")
			return
		}

		guard let payload = AdvertiseAckMessage(controlPort: controlPort).getPayload() else
		{
			gLogger.error("ServerPeer.onServerConnect: Failed to generate AdvertiseAck message for peer: \(socketAddress)")
			return
		}

		gLogger.network("ServerPeer.onServerConnect: Sending AdvertiseAck to peer \(peer.id)")
		if !peer.send(payload)
		{
			gLogger.error("ServerPeer.onServerConnect: Unable to send AdvertiseAck message to peer: \(socketAddress)")
			return
		}
	}

	/// Handle disconnections from a peer with an optional `reason`.
	///
	/// The base implementation will remove the peer from the server.
	override open func onDisconnect(reason: String?)
	{
		gLogger.info("ServerPeer.onDisconnect: Disconnecting from peer \(socketAddress?.description ?? "[none]"), with reason: \(reason ?? "[none given]")")

		if let socketAddress = self.socketAddress
		{
			guard let peer = server.findPeer(socketAddress: socketAddress) else
			{
				gLogger.error("ServerPeer.onDisconnect: Failed to locate peer")
				return
			}

			if !server.removePeer(id: peer.id, reason: reason)
			{
				gLogger.error("ServerPeer.onDisconnect: Failed to remove peer")
			}
		}

		super.onDisconnect(reason: reason)
	}

	/// Respond to ping from the given `peerSourceAddress`.
	///
	/// The base implementation will notify the local copy of the peer that it has received the ping ack.
	override open func onPingAck(from peerSourceAddress: Ipv4SocketAddress)
	{
		// Redirect these through the peer that sent the ping
		guard let peer = server.findPeer(socketAddress: peerSourceAddress) else
		{
			gLogger.error("ServerPeer.onPingAck: Failed to locate peer")
			return
		}

		peer.onPingAck(from: peerSourceAddress)
	}

	/// Handle payloads specific to a Seer-based server
	///
	/// The default implementation splits the payload up into separate function implementations. Much of this implementation stands
	/// alone, but the subclass implementation may wish to override some key methods that are triggered by incoming payloads. For
	/// examples, see `onSystemShutdown`, `onSystemReboot` and `onCheckForUpdates`.
	override open func onPayload(from peerSourceAddress: Ipv4SocketAddress, payload: Packet.Payload) -> Bool
	{
		// See if the super can handle the payload
		var superHandled = false
		if super.onPayload(from: peerSourceAddress, payload: payload) { superHandled = true }

		// Update the ping counter
		//
		// Note that we do this after letting the super have a crack at the payload because it may create the peer that we're
		// about to use.
		if let peer = server.findPeer(socketAddress: peerSourceAddress)
		{
			peer.pingsSentSinceLastResponse = 0
		}
		else
		{
			gLogger.network("SeerServerPeer.onPayload: Failed to locate peer (\(peerSourceAddress.description) for ping counter reset")
		}

		// If this was already handled, bail
		if superHandled { return true }

		// Check the payload, and if we handle it, do the work
		switch payload.info.id
		{
			case CommandMessage.payloadId:
				gLogger.network("SeerServerPeer.onPayload: [\(id)] received [CommandMessage] from source address \(peerSourceAddress)")
				if let message = CommandMessage.decode(from: payload.data)
				{
					onCommand(message)
				}
				return true

			case ConfigValueMessage.payloadId:
				gLogger.network("SeerServerPeer.onPayload: [\(id)] received [ConfigValueMessage] from source address \(peerSourceAddress)")
				if let message = ConfigValueMessage.decode(from: payload.data)
				{
					Config.onConfigValue(message: message)
				}
				return true

			case TriggerVibrationMessage.payloadId:
				gLogger.network("SeerServerPeer.onPayload: [\(id)] received [TriggerVibrationMessage] from source address \(peerSourceAddress)")
				onTriggerVibration()
				return true

			case ConfigValueListMessage.payloadId:
				gLogger.network("SeerServerPeer.onPayload: [\(id)] received [ConfigValueListMessage] from source address \(peerSourceAddress)")
				sendConfigValueList()
				return true

			default:
				// We don't handle this message, pass it along
				gLogger.network("SeerServerPeer.onPayload: [\(id)] received unknown Seer message: \(payload.info.id) from source address \(peerSourceAddress)")
				return false
		}
	}

	/// Run commands sent by the client
	open func onCommand(_ message: CommandMessage)
	{
		switch message.command
		{
			case CommandMessage.kShutdown:
				onSystemShutdown()

			case CommandMessage.kReboot:
				onSystemReboot()

			case CommandMessage.kCheckForUpdates:
				onCheckForUpdates()

			default:
				gLogger.warn("SeerServerPeer.onCommand: Command '\(message.command)' not supported")
		}
	}

	public static func buildConfigValueListMessage() -> ConfigValueListMessage
	{
		var message = ConfigValueListMessage()
		for (name, valueDict) in Config.configDict
		{
			// Skip non-public values
			if !(valueDict["public"] as? Bool ?? false) { continue }

			guard let description = (valueDict["description"] as? String) else { continue }
			guard let value = valueDict["value"] else { continue }
			guard let rawValueType = (valueDict["type"] as? String) else { continue }
			guard let type = Config.ValueType(rawValue: rawValueType) else
			{
				gLogger.error("SeerServerPeer.buildConfigValueListMessage: Unknown type '\(rawValueType)' for ConfigValueList message")
				continue
			}
			guard let configValue = ConfigValueListMessage.ConfigValue(name: name, type: type, value: value, description: description) else
			{
				gLogger.error("SeerServerPeer.buildConfigValueListMessage: Unable to create ConfigValue for \(name)")
				continue
			}
			message.configValues.append(configValue)
		}

		return message
	}

	open func sendConfigValueList()
	{
		guard let payload = SeerServerPeer.buildConfigValueListMessage().getPayload() else
		{
			gLogger.error("SeerServerPeer.sendConfigValueList: Failed to create ConfigValueListMessage payload")
			return
		}

		server.send(payload: payload)
	}

	open func onTriggerVibration()
	{
		gLogger.info("SeerServerPeer.onTriggerVibration: Triggering vibration to all clients")
		guard let payload = TriggerVibrationMessage().getPayload() else
		{
			gLogger.error("SeerServerPeer.onTriggerVibration: Failed to create TriggerVibration message payload")
			return
		}

		server.send(payload: payload)
	}

	open func onSystemShutdown()
	{
		// Override this
	}

	open func onSystemReboot()
	{
		// Override this
	}

	open func onCheckForUpdates()
	{
		// Override this
	}

	/// Provides access to the active `MediaProvider`
	open func getMediaProvider() -> MediaProvider?
	{
		// Override this
		return nil
	}
}
