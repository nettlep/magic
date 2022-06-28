//
//  Peer.swift
//  Minion
//
//  Created by Paul Nettle on 2/20/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// A peer that has been successfully authenticated and connected
///
/// Peers are accumulated from discovery listeners. Each peer has the relevant information required to communicate with it
/// along with a time it was last heard from. The latter is used to determine if the peer is still active, and if not, may
/// be removed.
open class Peer
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The number of ping failures in order to consider the peer timed out and not responding
	public static let kPingFailedTimeoutCount: Int = 20

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The socket for communicating with this peer
	public var socket: Socket?

	/// The remote peer's address information (the address:port used to send to this peer)
	public var socketAddress: Ipv4SocketAddress?

	/// The identifier string for this peer (just the `socketAddress` in string form)
	public var id: String { return "\(socketAddress?.description ?? "[none]")" }

	/// The number of pings that have been since to the peer since the last time a ping was received
	///
	/// As pings are sent to peers, this value is incremented.
	/// As pings are received, this value is set to zero
	/// If this value gets too large, then too many ping intervals have transpired and the peer should be disconnected
	public var pingsSentSinceLastResponse: Int = 0

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization and deinitialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Construct a peer at the given `socketAddress`
	public init?(socketAddress: Ipv4SocketAddress? = nil)
	{
		if !initSocket() { return nil }
		self.socketAddress = socketAddress
	}

	/// Creates the socket for talking to this peer
	private func initSocket() -> Bool
	{
		if socket != nil
		{
			gLogger.network("Peer.initSocket: Closing existing peer socket (fd = \(socket!.fd))")
			_=socket?.close()
			socket = nil
		}

		socket = Socket.createUdpSocket()
		if socket == nil
		{
			gLogger.error("Peer.initSocket: Failed to create UDP socket")
			return false
		}

		gLogger.network("Peer.initSocket: Setting up socket (fd = \(socket!.fd)) for peer \(id) on socket")
		return true
	}

	/// Cleans up a peer and notifies remote peer that we are disconnecting
	open func hangup() -> Bool
	{
		gLogger.network("Peer.hangup: Hanging up peer \(id)")

		// Connected peers should notify their remote peer that the connection is going down
		if nil != socketAddress
		{
			// Notify peer that we are disconnecting
			if !send(DisconnectMessage(reason: "Device shut down"))
			{
				gLogger.error("Peer.hangup: Failed to send Disconnect message to peer \(id)")
				return false
			}

			// Let ourselves know we're disconnected
			onDisconnect(reason: "Hangup")
		}

		return true
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Overrides
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Override this method to handle connection events for server-side connections (only!)
	///
	/// The superclass may provide important functionality, so be sure to call it.
	open func onServerConnect(from socketAddress: Ipv4SocketAddress)
	{
		// Update the socket address for our peer
		self.socketAddress = socketAddress
	}

	/// Override this method to handle connection events for client-side connections (only!)
	///
	/// The superclass may provide important functionality, so be sure to call it.
	open func onClientConnect(from socketAddress: Ipv4SocketAddress)
	{
		// Update the socket address for our peer
		self.socketAddress = socketAddress
	}

	/// Called when an existing peer disconnects with an optional `reason` for the disconnect
	///
	/// The superclass may provide important functionality, so be sure to call it.
	///
	/// If a peer is already connected and re-connects through a broadcast message, the `onDisconnect()` will be called before
	/// the peer connection is re-established, resulting in a subsequent call to `onServerConnect()` or `onClientConnect()` for
	/// server or client peers respectively.
	open func onDisconnect(reason: String?)
	{
		// Remove the current connected peer
		self.socketAddress = nil
	}

	/// Called when a ping is received
	///
	/// Subclasses are not required do anything here, the default implementation fully manages pings.
	///
	/// The superclass may provide important functionality, so be sure to call it.
	open func onPing()
	{
		// Default implementation does nothing at the moment
	}

	/// Called when a ping acknowledgement is received
	///
	/// Subclasses are not required do anything here, the default implementation fully manages pings.
	///
	/// The superclass may provide important functionality, so be sure to call it.
	open func onPingAck(from peerSourceAddress: Ipv4SocketAddress)
	{
		// Default implementation does nothing at the moment - we reset the ping timer each time we receive anything from the peer
	}

	/// Called when a peer sends data to the server
	///
	/// Subclasses will generally want to override this in order to receive data from their peer.
	///
	/// The default functionality is to manage handshake messages. This method should return `true` if the message was handled,
	/// otherwise `false`. Note that the default implementation will return true for all handshake messages, even if there was
	/// a failure (as it is considered the default implementation's job to manage those and not pass them through.)
	///
	/// The superclass provides important functionality, so be sure to call it.
	open func onPayload(from peerSourceAddress: Ipv4SocketAddress, payload: Packet.Payload) -> Bool
	{
		// We received something (anything) from the peer, therefore, we know they're alive
		pingsSentSinceLastResponse = 0

		switch payload.info.id
		{
			case DisconnectMessage.payloadId:
				let message = DisconnectMessage.decode(from: payload.data)
				if nil == message
				{
					gLogger.warn("Peer.onPayload[DisconnectMessage]: Failed to decode message [\(id)] from source address \(peerSourceAddress)")
				}
				else
				{
					gLogger.network("Peer.onPayload[DisconnectMessage]: Received [\(id)] from source address \(peerSourceAddress)")
				}

				onDisconnect(reason: message?.reason)

			case PingMessage.payloadId:
				if nil == PingMessage.decode(from: payload.data)
				{
					gLogger.warn("Peer.onPayload[PingMessage]: Failed to decode message")
				}
				else
				{
					gLogger.networkData("Peer.onPayload[PingMessage]: Received [\(id)] from source address \(peerSourceAddress)")
				}

				onPing()

			case PingAckMessage.payloadId:
				if nil == PingAckMessage.decode(from: payload.data)
				{
					gLogger.warn("Peer.onPayload[PingAckMessage]: Failed to decode message [\(id)] received from source address \(peerSourceAddress)")
				}
				else
				{
					gLogger.networkData("Peer.onPayload[PingAckMessage]: Received [\(id)] from source address \(peerSourceAddress)")
				}

				onPingAck(from: peerSourceAddress)

			case AdvertiseMessage.payloadId:
				guard let message = AdvertiseMessage.decode(from: payload.data) else
				{
					gLogger.error("Peer.onPayload[AdvertiseMessage]: Failed to decode message [\(id)] from source address \(peerSourceAddress)")
					return true
				}

				let socketAddress = Ipv4SocketAddress.init(address: peerSourceAddress.address, port: message.controlPort)
				gLogger.network("Peer.onPayload[AdvertiseMessage]: Advertiser source: \(peerSourceAddress), target: \(socketAddress)")

				// Hand it off to the receiver
				onServerConnect(from: socketAddress)

			case AdvertiseAckMessage.payloadId:
				guard let message = AdvertiseAckMessage.decode(from: payload.data) else
				{
					gLogger.error("Peer.onPayload[AdvertiseAckMessage]: Failed to decode message from source address \(peerSourceAddress)")
					return true
				}

				let socketAddress = Ipv4SocketAddress.init(address: peerSourceAddress.address, port: message.controlPort)
				gLogger.network("Peer.onPayload[AdvertiseAckMessage]: AdvertiserAck source: \(peerSourceAddress), target: \(socketAddress)")

				// Hand it off to the receiver
				onClientConnect(from: socketAddress)

			default:
				// We don't handle this message, pass it along
				//gLogger.networkData("Peer.onPayload: [\(id)] received unknown message: \(payload.info.id) from source address \(peerSourceAddress)")
				return false
		}

		return true
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// General implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Pings the peer and checks availability
	///
	/// Returns `true` if this peer is still alive, otherwise `false`
	open func ping() -> Bool
	{
		// Is this peer still alive?
		if pingsSentSinceLastResponse > Peer.kPingFailedTimeoutCount
		{
			// The peer has timed out
			return false
		}

		// Track our ping count
		pingsSentSinceLastResponse += 1

		// We can't do much about errors here, but since any real failures will eventually lead to a disconnect anyway, that's OK
		gLogger.networkData("Peer.ping: Sending ping to peer \(id)")
		if !send(PingMessage())
		{
			gLogger.warn("Peer.ping: Failed to send ping to peer \(id)")
		}

		// This peer is, as far as we know, still active
		return true
	}

	/// Send a message to the peer
	open func send(_ message: NetMessage) -> Bool
	{
		if nil == socketAddress
		{
			gLogger.error("Peer.send(message:): Attempt to send message without a valid peer connection")
			return false
		}
		if nil == socket
		{
			if !initSocket()
			{
				gLogger.warn("Peer.send(message:): Failed to create socket for send")
				return false
			}
		}

		if message.getPayload()?.send(to: socketAddress!, over: socket!) ?? false { return true }

		gLogger.warn("Peer.send(message:): Failed to send message, recreating socket after first failure")

		// If it fails, recreate the socket and try one more time
		if !initSocket()
		{
			gLogger.warn("Peer.send(message:): Failed to recreate socket after first failure")
			return false
		}

		return message.getPayload()?.send(to: socketAddress!, over: socket!) ?? false
	}

	/// Send a payload to the peer
	open func send(_ packet: Packet) -> Bool
	{
		if nil == socketAddress
		{
			gLogger.warn("Peer.send(packet:): Attempt to send packet without a valid peer connection")
			return false
		}
		if nil == socket
		{
			if !initSocket()
			{
				gLogger.warn("Peer.send(packet:): Failed to create socket for send")
				return false
			}
		}

		if packet.send(to: socketAddress!, over: socket!) { return true }

		gLogger.warn("Peer.send(packet:): Failed to send packet, recreating socket after first failure")

		// If it fails, recreate the socket and try one more time
		if !initSocket()
		{
			gLogger.warn("Peer.send(packet:): Failed to recreate socket after first failure")
			return false
		}

		return packet.send(to: socketAddress!, over: socket!)
	}

	/// Send a payload to the peer
	open func send(_ payload: Packet.Payload) -> Bool
	{
		if nil == socketAddress
		{
			gLogger.warn("Peer.send(payload:): Attempt to send payload without a valid peer connection")
			return false
		}
		if nil == socket
		{
			if !initSocket()
			{
				gLogger.warn("Peer.send(payload:): Failed to create socket for send")
				return false
			}
		}

		if payload.send(to: socketAddress!, over: socket!) { return true }

		gLogger.warn("Peer.send(payload:): Failed to send payload, recreating socket after first failure")

		// If it fails, recreate the socket and try one more time
		if !initSocket()
		{
			gLogger.warn("Peer.send(payload:): Failed to recreate socket after first failure")
			return false
		}

		return payload.send(to: socketAddress!, over: socket!)
	}
}
