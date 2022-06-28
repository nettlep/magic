//
//  DiscoveryAdvertiser.swift
//  Minion
//
//  Created by Paul Nettle on 1/26/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import Dispatch

/// Discovery Advertisement
///
/// Discovery happens by a `DiscoveryListener` silently waiting to hear from an advertiser (a `DiscoveryAdvertiser` instance) and
/// responding in kind. Note that the response is not directed at the advertising instance, but rather, to the `clientControlPort`
/// that was used when initiating the advertisement. It is up to the controlling code to start this advertiser, wait for the
/// response on its own control port, and then stop this advertiser.
public class DiscoveryAdvertiser
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The frequency at which we send broadcast advertise messages
	public static let kAdvertiseFrequencyMS: Int = 1000

	/// The sleep intervals as we wait `kAdvertiseFrequencyMS` milliseconds to send advertisements
	public static let kAdvertiseSleepIntervalMS = WaitWorker.kDefaultSleepIntervalMS

	/// The number of `kAdvertiseSleepIntervalMS` periods to wait for a successful stop
	public static let kStopWaitTimeMS: Int = kAdvertiseSleepIntervalMS * 10

	// -----------------------------------------------------------------------------------------------------------------------------
	// Types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The current discovery active state
	public enum State
	{
		case Starting
		case Active
		case Stopping
		case Stopped
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Current state
	internal var state: State

	/// Accessor for the starting state
	public var isStarting: Bool { return state == .Starting }

	/// Accessor for the active state
	public var isActive: Bool { return state == .Active }

	/// Accessor for the stopping state
	public var isStopping: Bool { return state == .Stopping }

	/// Accessor for the stopped state
	public var isStopped: Bool { return state == .Stopped }

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization and deinitialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initializes our object
	///
	/// See `start()` to initiate discovery
	public init()
	{
		self.state = .Stopped
	}

	/// Cleanup - ensures our discovery threads are stopped
	deinit
	{
		// Ensure we're not transmitting anything
		if !stop()
		{
			gLogger.error("DiscoveryAdvertiser.deinit: Failed to stop discovery during deinit")
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Processing
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Starts the discovery advertiser
	///
	/// If the advertiser is already active, this method immediately returns true.
	///
	/// Set `local` to true to advertise locally (and not over broadcast)
	///
	/// Returns `true` if advertisement was successfully initiated, `false` otherwise.
	public func start(interface: Ipv4Interface? = nil, discoveryPort: UInt16, clientControlPort: UInt16, loopback: Bool = false) -> Bool
	{
		// If we are already in the correct state, return true
		if isActive { return true }

		gLogger.network("DiscoveryAdvertiser.start: Starting on discovery port \(discoveryPort) with control port \(clientControlPort)")

		gLogger.network(" > DiscoveryAdvertiser.start: Starting advertise loop for all interfaces on port \(discoveryPort)")

		var socket: Socket?
		DispatchQueue.global(qos: .userInteractive).async
		{
			self.state = .Active

			while self.isActive
			{
				if socket == nil
				{
					socket = Socket.createUdpSocket(enableBroadcast: true)

					if socket == nil
					{
						gLogger.error("DiscoveryAdvertiser: Unable to create socket for broadcast send")
						break
					}
					else
					{
						gLogger.network("DiscoveryAdvertiser: Advertiser running on socket (fd = \(socket!.fd)) with broadcast enabled")
					}
				}

				gLogger.networkData("DiscoveryAdvertiser: Sending broadcast advertisement")

				// We can't really do much about any errors and the socket would have logged them, so we ignore them
				if let payload = AdvertiseMessage(controlPort: clientControlPort).getPayload()
				{
					let dest = Ipv4SocketAddress(address: loopback ? Ipv4Address.kLoopback : Ipv4Address.kBroadcast, port: discoveryPort)
					gLogger.networkData("DiscoveryAdvertiser: Sending AdvertiseMessage to \(dest.description) on socket (fd = \(socket!.fd))")

					if !payload.send(to: dest, over: socket!)
					{
						gLogger.warn("DiscoveryAdvertiser: Failed to send, shutting down broadcast socket (fd = \(socket!.fd)); will recreate socket and try again")
						_=socket?.close()
						socket = nil
					}
				}

				_ = WaitWorker.execFor(DiscoveryAdvertiser.kAdvertiseFrequencyMS, intervalMS: DiscoveryAdvertiser.kAdvertiseSleepIntervalMS)
				{
					return !self.isActive
				}
			}

			self.state = .Stopped
			if let interface = interface
			{
				gLogger.network("DiscoveryAdvertiser: Deactivated for interface \(interface)")
			}
			else
			{
				gLogger.network("DiscoveryAdvertiser: Deactivated for all interfaces")
			}

			gLogger.network("DiscoveryAdvertiser: Stopping discovery litener. Broadcast socket (fd = \(socket==nil ? "[nil]" : "\(socket!.fd)")) shut down")
			_=socket?.close()
			socket = nil
		}

		return true
	}

	/// Stops any active discovery advertisement
	///
	/// If discovery advertisement is not currently active, this method returns `true` immediately.
	///
	/// Returns `true` if the active discovery has been successfully terminated, `false` otherwise.
	public func stop() -> Bool
	{
		// If we're already stopped, return success
		if isStopping || isStopped { return true }

		// Simply setting this will trigger discovery termination on our threads
		state = .Stopping

		// Wait for discovery to terminate
		_ = WaitWorker.execFor(DiscoveryAdvertiser.kStopWaitTimeMS, intervalMS: 1)
		{
			return self.isStopped
		}

		// Return success if we're stopped
		return isStopped
	}
}
