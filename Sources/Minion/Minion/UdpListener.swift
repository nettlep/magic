//
//  UdpListener.swift
//  Minion
//
//  Created by Paul Nettle on 1/31/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import Dispatch

/// A generic UDP listener implementation
///
/// A listener is first initialized and then started (via `start()`) with a receiver block. The block is called for each received
/// payload. To stop the listener, simply call `stop()`.
public class UdpListener
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The frequency at which we listen for messages (broadcast or otherwise)
	public static let kDefaultListenFrequencyMS: Int = 15

	/// Number of total listen iterations to wait when stopping
	public static let kStopIterationCount = 4

	// -----------------------------------------------------------------------------------------------------------------------------
	// Types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Callback for received data
	///
	/// The method should return 'true' to continue listening, otherwise false
	public typealias Receiver = (_ fromSourceAddress: Ipv4SocketAddress, _ payload: Packet.Payload) -> Bool

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Determines if the listener is currently running
	private(set) public var isActive = AtomicFlag()

	/// Determines if our listener is currently stopping
	private var isStopping = false

	/// How long to wait for data while listening before iterating through the event loop
	private let listenFrequencyMS: Int

	/// The local address where data is received
	private(set) public var receiveAddress = Atomic<Ipv4SocketAddress>(Ipv4SocketAddress(address: 0, port: 0))

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization and deinitialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Standard initializer
	public init(listenFrequencyMS: Int = UdpListener.kDefaultListenFrequencyMS)
	{
		self.listenFrequencyMS = listenFrequencyMS
	}

	/// Cleanup - ensures our discovery threads are stopped
	deinit
	{
		// Ensure we're not transmitting anything
		if !stop()
		{
			gLogger.error("UdpListener.init: Failed to stop UDP listener during deinit")
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Starts a listener with a callback for data received with an optional port to listen on.
	///
	/// If the listener is already active, this method will immediately return `nil`
	///
	/// If the interface is unspecified, the default is `nil` (all interfaces)
	///
	/// If `receiver` returns false, the listener is terminated. See `UdpListener.Receiver` for more information.
	///
	/// Returns true if started, otherwise false.
	public func start(interface: Ipv4Interface? = nil, port: UInt16, broadcastListener: Bool = false, loopback: Bool = false, receiver: @escaping Receiver) -> Bool
	{
		// If we are already in the correct state, return true
		if isActive.value { return true }

		//gLogger.network("UdpListener.start: Starting \(broadcastListener ? "broadcast listener " : "")on \(nil != interface ? "\(interface!)" : "all interfaces"), port \(port)")

		// Set the states
		isStopping = false
		isActive.value = true

		DispatchQueue.global(qos: .userInteractive).async
		{
			var socket: Socket?
			while true
			{
				if socket == nil
				{
					// Create our UDP socket
					socket = Socket.createUdpSocket(enableBroadcast: broadcastListener)

					if socket == nil
					{
						gLogger.error("> UdpListener.start: Failed to create socket")
						break
					}

					// Make it non-blocking by setting a small timeout
					if !socket!.setReceiveTimeout(timeoutMS: self.listenFrequencyMS)
					{
						gLogger.error("> UdpListener.start: Failed to set receive timeout on the socket")
						break
					}

					// Default the receiveAddress to any address
					self.receiveAddress.mutate { $0 = Ipv4SocketAddress(address: loopback ? Ipv4Address.kLoopback : Ipv4Address.kAny, port: port) }

					// If we have an interface, bind to it
					if let interface = interface
					{
						// Our broadcast address, taking local connections into account
						let broadcastAddress = loopback ? Ipv4Address.kLoopback : Ipv4Address.kAny

						// Set our receive address
						self.receiveAddress.mutate { $0 = Ipv4SocketAddress(address: broadcastListener ? broadcastAddress : interface.address, port: port) }

						// Bind to the interface
						gLogger.network(" > UdpListener.start: Binding to interface: \(interface)")
						if !socket!.bindToInterface(interface)
						{
							gLogger.error(" > UdpListener.start: Failed to bind socket to the interface")
							break
						}
					}

					// Bind to the address
					gLogger.network(" > UdpListener.start: Binding socket (fd = \(socket!.fd)) for \(broadcastListener ? "broadcast":"control channel") listen to address \(self.receiveAddress.value.toString())")
					if !socket!.bind(to: self.receiveAddress.value)
					{
						gLogger.error(" > UdpListener.start: Failed to bind to local address \(self.receiveAddress.value.toString()) (errno[\(errno)]: \(String(cString: strerror(errno))))")
						break
					}
				}

				// Is our listener stopping
				if !self.isActive.value || self.isStopping { break }

				// Try to get some data
				guard let (data, sender) = self.receive(overSocket: socket!) else
				{
					// We got an error and need to reconnect
					gLogger.warn("UdpListener.start: Failed to receive from socket (fd = \(socket!.fd)), will recreate socket and try again")
					_=socket?.close()
					socket = nil
					continue
				}

				// Deal with the data we just received
				if let recvData = data, let recvSender = sender
				{
					// Decode it
					if let payload = Packet.deconstruct(fromData: recvData)
					{
						// Notify our receiver delegate
						//
						// If `receiver` returns `false`, they have asked to stop listening
						if !receiver(recvSender, payload) { break }
					}
					else
					{
						gLogger.error("UdpListener.start: Unable to decode packet")
						continue
					}
				}
			}

			self.isActive.value = false
			self.isStopping = false
			gLogger.network("UdpListener.start: Stopped for local address \(self.receiveAddress.value.toString())")
		}

		return true
	}

	/// Stops the active listener
	///
	/// If the listener is not currently active or already stopping, this method returns `true` immediately.
	///
	/// The parameter `stopListenTimeoutCount` represents the number of listen timeouts to wait for a stop.
	///
	/// Returns `true` if the active listener has been successfully terminated, `false` otherwise.
	public func stop() -> Bool
	{
		// If we're already stopped, return success
		if !isActive.value || isStopping { return true }

		// Simply setting this will trigger listener termination on our threads
		isStopping = true

		// Wait for discovery to terminate
		return WaitWorker.execFor(listenFrequencyMS * UdpListener.kStopIterationCount)
		{
			return !isActive.value
		}
	}

	/// Receives data from the given `source` on `socket`.
	///
	/// Returns a `Data` object containing the received data and an `Ipv4SocketAddress` referecing the sender. If no data is
	/// available, both will be `nil`. If an error occurs, this method will return `nil`
	private func receive(overSocket socket: Socket) -> (Data?, Ipv4SocketAddress?)?
	{
		guard let (data, sender) = socket.recv() else
		{
			// No data available at the moment
			if errno == EAGAIN { return (nil, nil) }

			gLogger.error("UdpListener.receive: Listener recv (fd = \(socket.fd)) failed (errno[\(errno)]: \(String(cString: strerror(errno))))")
			return nil
		}

		return (data, sender)
	}
}
