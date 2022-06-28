//
//  Server.swift
//  Minion
//
//  Created by Paul Nettle on 2/12/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import CoreFoundation
import Dispatch

/// The server class manages connections and incoming data from peers that connect via broadcast message.
///
/// Use `start()` to start the server, it will return a peer that represents the server's control channel peer.
///
/// While the server is active (see `isStarted`) a broadcast listener will be available on the discovery port (see
/// `Server.kDefaultDiscoveryPort`) to accept advertisment `Packet`s from peers wishing to initiate a connection.
///
/// In addition to a broadcast listener, the server will also listen for peer `Packet`s on the control port (see
/// `Server.kDefaultControlPort`.) Only authenticated packets from connected peers will be accepted. All other packets will be
/// silently dropped on the floor.
///
/// Payload data (see `Packet.Payload`) from valid peers will be notified through the `onPayload()` method from the
/// `Peer` protocol.
///
/// In order to ensure peer connectivity, the server will send a periodic ping request (see `Server.kPingFrequencySeconds`)
/// to each peer. If a peer does not respond after `Server.kPingFailedTimeoutCount` pings, the peer is automatically disconnected
/// (and `onDisconnect()` is called from `Peer`.)
///
/// Use `stop()` to stop the server. This will send a disconnect message to each peer and close their connections locally,
/// calling the `onDisconnect()` method from `Peer` for each connected peer.
public class Server
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Pinger dispatch queue
	private static let kServerDispatchQueue = DispatchQueue(label: "com.paulnettle.minion.Server")

	/// Set to `true` if we should bind the discovery listenter to all interfaces, otherwise `false`
	private static let kBindToInterfaces = false

	/// The default port used for broadcast discovery
	///
	/// This can be overridden in `start`
	public static let kDefaultDiscoveryPort: UInt16 = 54670

	/// The default port used for control channel communications
	///
	/// This can be overridden in `start`
	public static let kDefaultControlPort: UInt16 = kDefaultDiscoveryPort + 1

	/// The frequency of pings sent to the peer
	public static let kPingFrequencySeconds: TimeInterval = 1

	// -----------------------------------------------------------------------------------------------------------------------------
	// Types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Factory used to create peers
	///
	/// This factory is used by the `start` method to create the `Peer` that represents this server. This allows callers to create
	/// custom `Peer` classes to handle application-specific packets.
	public typealias PeerFactory = (_ socketAddress: Ipv4SocketAddress, _ server: Server) -> Peer?

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Our listener for control channel messages
	private var controlChannelListener: UdpListener?

	/// Our listeners for broadcast messages, one per interface
	private var broadcastListeners = [DiscoveryListener]()

	/// The port address used for receiving broadcast announcements
	///
	/// This value will be `nil` if the server is not fully started
	private(set) public var discoveryPort: UInt16?

	/// The port address used for receiving control channel messages
	///
	/// This value will be `nil` if the server is not fully started
	private(set) public var controlPort: UInt16?

	/// Timer used to send out periodic pings to all peers
	// private var pingTimer: Timer?
	private var pingTimer: DispatchSourceTimer?

	/// Returns true if the server is started
	public var isStarted: Bool { return nil != controlChannelListener && nil != serverPeer && broadcastListeners.count > 0 }

	/// List of active peers that were discovered via listening
	private var peers = [Peer]()

	/// Returns the number of connected peers
	public var connectedPeers: Int { return peers.count }

	/// The peer for managing server communications
	public private(set) var serverPeer: Peer?

	/// Synchronous accessor for meta blocks
	private let peersMutex = PThreadMutex()

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization & deinitialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Our public init method
	public init()
	{
	}

	/// Stops this server automatically when it is deinitialized
	deinit
	{
		stop()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// This method is called each time we receive data from the broadcast listener
	///
	/// If this method returns `false`, the `DiscoveryListener` will be stopped. See `UdpListener.Receiver` for more information.
	private func discoveryReceiver(from sourceAddress: Ipv4SocketAddress, payload: Packet.Payload) -> Bool
	{
		if let serverPeer = serverPeer
		{
			// Send it to our peer (which handles all incoming data, including broadcast messages)
			if !serverPeer.onPayload(from: sourceAddress, payload: payload)
			{
				gLogger.error("Server.discoveryReceiver: Unhandled payload received from broadcast listener")
			}
		}
		else
		{
			gLogger.error("Server.discoveryReceiver: No server peer to handle broadcast payload")
		}

		return true
	}

	/// This method is called each time we receive data over the control-channel listener
	///
	/// If this method returns `false`, the `UdpListener` will be stopped. See `UdpListener.Receiver` for more information.
	private func controlChannelReceiver(from sourceAddress: Ipv4SocketAddress, payload: Packet.Payload) -> Bool
	{
		if let serverPeer = serverPeer
		{
			// Send it to our peer
			if !serverPeer.onPayload(from: sourceAddress, payload: payload)
			{
				gLogger.error("Server.controlChannelReceiver: Unhandled payload received from control channel listener")
			}
		}
		else
		{
			gLogger.error("Server.controlChannelReceiver: No server peer to handle control channel payload")
		}

		return true
	}

	/// Manage pinging peers to ensure connectivity.
	///
	/// This method is called periodically on a scheduled `Timer` event. It should be called every `kPingFrequencySeconds`
	/// seconds.
	///
	/// This method performs two critical tasks:
	///
	///     1. Checks each peer for the period of time that has passed since their last ping response. If it exceeds
	///        `kPingFailedTimeoutCount` ping durations, then the peer is disconnected and removed from the system.
	///     2. Sends pings to each peer in order to keep connections alive
	private func periodicPinger()
	{
		// Check each peer to see if it is still alive
		//
		// We traverse the list of peers in reverse order to allow for easy deletion of peers
		var peersToDelete = [String]()
		peersMutex.fastsync
		{
			for peer in peers
			{
				if !peer.ping()
				{
					peersToDelete.append(peer.id)
				}
			}
		}

		// Remove any peers we've decided should go away
		for id in peersToDelete
		{
			_ = removePeer(id: id, reason: "Connection timed out")
		}
	}

	/// Starts the server
	///
	/// This method starts the server. Use `isStarted` to determine if the server is live and active.
	///
	/// An active server maintains a broadcast listener on `discoveryPort` (if unspecified, `Server.kDefaultDiscoveryPort` is used)
	/// for connection requests. In addition, the server will maintain a listener on `controlPort` (if unspecified,
	/// `Server.kDefaultControlPort` is used) for control channel messages and peer data.
	///
	/// The discovery listeners are started on each network interface device. If one listener fails for an interface, the interface
	/// is discarded. If no discovery listeners can be started, this method will return `false`.
	///
	/// This method returns `true` if discovery/control listeners could be started on at least one interface, otherwise `false`
	public func start(discoveryPort: UInt16 = Server.kDefaultDiscoveryPort, controlPort: UInt16 = Server.kDefaultControlPort, loopback: Bool, peerFactory: PeerFactory ) -> Peer?
	{
		gLogger.network("Server.start: Starting on discovery port \(discoveryPort), control port \(controlPort)")

		// Start our discovery listeners
		var broadcastListeners = [DiscoveryListener]()

		if Server.kBindToInterfaces
		{
			for interface in Ipv4Interface.enumerateInterfaces(requireBroadcast: false)
			{
				let broadcastListener = DiscoveryListener()
				if broadcastListener.start(interface: interface, discoveryPort: discoveryPort, loopback: loopback, receiver: discoveryReceiver)
				{
					broadcastListeners.append(broadcastListener)
				}
			}
		}
		else
		{
			let broadcastListener = DiscoveryListener()
			if broadcastListener.start(interface: nil, discoveryPort: discoveryPort, loopback: loopback, receiver: discoveryReceiver)
			{
				broadcastListeners.append(broadcastListener)
			}
		}

		// If we can't start a discovery listener, we have an error
		if broadcastListeners.isEmpty
		{
			gLogger.error("Server.start: Unable to find a valid interface for server")
			return nil
		}

		// Start our control channel listener
		let controlChannelListener = UdpListener()
		if !controlChannelListener.start(interface: nil, port: controlPort, loopback: loopback, receiver: controlChannelReceiver)
		{
			gLogger.error("Server.start: Failed to start the UdpListener for all interfaces on control port \(controlPort)")
			stop()
			return nil
		}

		// Start a timer to send pings out periodically
		pingTimer = DispatchSource.makeTimerSource(flags: .strict)
		pingTimer!.setEventHandler(handler: periodicPinger)
		pingTimer!.schedule(deadline: .now(), repeating: Server.kPingFrequencySeconds, leeway: .milliseconds(1))
		pingTimer!.resume()

		// All good, setup our listeners
		self.controlChannelListener = controlChannelListener
		self.broadcastListeners = broadcastListeners
		self.discoveryPort = discoveryPort
		self.controlPort = controlPort
		self.serverPeer = peerFactory(controlChannelListener.receiveAddress.value, self)

		// Sanity check, just in case!
		if !isStarted
		{
			gLogger.error("Server.start: Server has failed to start")
			return nil
		}

		// Return a peer for handling our control channel activity
		return self.serverPeer
	}

	/// Stops all broadcast and control channel listeners, if active
	public func stop()
	{
		gLogger.network("Server.stop: Server is stopping")

		// Stop the ping timer
		self.pingTimer?.cancel()
		self.pingTimer = nil

		// Stop our broadcast listeners
		for broadcastListener in broadcastListeners
		{
			_ = broadcastListener.stop()
		}

		// Clear out the list
		broadcastListeners.removeAll()

		// Remove all peers (this also sends them a disconnect message)
		while peers.count > 0
		{
			let id = peers.first!.id
			if !peers.first!.hangup()
			{
				gLogger.error("Server.stop: Failed to hangup peer: \(peers.first!.id)")
			}

			if !removePeer(id: id, reason: "Device shutting down")
			{
				gLogger.warn("Server.stop: Failed to notify peer of disconnect")
			}
		}

		// Stop our control channel listener
		_ = controlChannelListener?.stop()
		controlChannelListener = nil

		// Clean up
		discoveryPort = nil
		controlPort = nil

		gLogger.info("Server.stop: Server is stopped")
	}

	/// Send a payload to all connected peers
	public func send(payload: Packet.Payload)
	{
		peersMutex.fastsync
		{
			for peer in self.peers
			{
				if !peer.send(payload)
				{
					gLogger.error("Server.send: Unable to send payload (\(payload.data.count) bytes) to peer \(peer.id)")
				}
			}
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Peer management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the peer with the given ID or `nil` if not found
	public func findPeer(id: String) -> Peer?
	{
		return peersMutex.fastsync
		{
			for peer in peers
			{
				if peer.id == id { return peer }
			}

			return nil
		}
	}

	/// Retiurns an optional `Peer` with the given `Ipv4SocketAddress`.
	///
	/// If no `Peer` is found, this method returns nil.
	public func findPeer(socketAddress: Ipv4SocketAddress) -> Peer?
	{
		return peersMutex.fastsync
		{
			for peer in peers
			{
				if let peerAddress = peer.socketAddress
				{
					if peerAddress.address == socketAddress.address { return peer }
				}
			}

			return nil
		}
	}

	/// Removes the first peer associated with the given socket address
	///
	/// If multiple peers exist, then you should call this method multiple times until it returns `false`.
	///
	/// Returns true on success, or false if the peer was not found
	public func removePeer(id: String, reason: String?) -> Bool
	{
		return peersMutex.fastsync
		{
			// Search for the peer
			for i in 0..<self.peers.count
			{
				if peers[i].id == id
				{
					// Notify the peer of the disconnection
					if let reason = reason
					{
						// Send the peer a disconnection message
						gLogger.network("Server.removePeer: Disconecting peer \(id) with reason: \(reason)")

						peers[i].onDisconnect(reason: reason)
					}

					self.peers.remove(at: i)

					gLogger.network("Server.removePeer: Peer \(id) removed. Current peer count: \(peers.count)")
					return true
				}
			}

			return false
		}
	}

	/// Adds a peer to the list of peers
	///
	/// This method does not check to see if the peer already exists and may therefore add duplicate peers. If this is not the
	/// behavior you want, use `removePeer(socketAddress:reason)` to remove the existing peer.
	public func addPeer(socketAddress: Ipv4SocketAddress) -> Peer?
	{
		// This is not technically necessary, as we'll ping timeout rather quickly.
		// If this peer exists, remove it first
		if let existingPeer = findPeer(socketAddress: socketAddress)
		{
			gLogger.network("Server.addPeer: Peer \(existingPeer.id) exists, removing prior to reconnecting")
			if !removePeer(id: existingPeer.id, reason: nil)
			{
				gLogger.error("Server.addPeer: Failed to remove existing peer: \(existingPeer.id)")
			}
		}

		return peersMutex.fastsync
		{
			// Add the new peer
			guard let newPeer = Peer(socketAddress: socketAddress) else { return nil }

			// Add the peer
			self.peers.append(newPeer)

			gLogger.debug("Server.addPeer: Peer \(newPeer.id) added. Current peer count: \(peers.count)")
			return newPeer
		}
	}
}
