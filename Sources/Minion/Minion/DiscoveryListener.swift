//
//  DiscoveryListener.swift
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

/// Listens for clients reaching out through our discovery interface
///
/// Clients must properly authenticate by signing their discovery packet with a shared secret
public class DiscoveryListener
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The frequency at which we listen for messages (broadcast or otherwise)
	public static let kDefaultListenFrequencyMS = UdpListener.kDefaultListenFrequencyMS

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Our UDP listener, which we use to listen for broadcast messages
	private var listener: UdpListener?

	/// The delegate thatg receives connection notifications
	private var receiver: UdpListener.Receiver?

	/// Returns true if the discovery listener is currently active
	public var isActive: Bool { return listener != nil }

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization and deinitialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Standard initializer, required for public interface
	public init()
	{
	}

	/// Ensure the listener is stopped on deinit
	deinit
	{
		// Ensure we're not listening any longer
		if !stop()
		{
			gLogger.error("Failed to stop discovery listener during deinit")
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Processing
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Starts the discovery process
	///
	/// If the Listener is already active, this method immediately returns true.
	///
	/// If `receiver` returns false, the listener is terminated. See `DiscoveryListener.ConnectionReceiver` for more information.
	///
	/// Set `local` to true to advertise locally (and not over broadcast)
	///
	/// Returns `true` if the listen was successfully initiated, `false` otherwise.
	public func start(interface: Ipv4Interface?, discoveryPort: UInt16, loopback: Bool, receiver: @escaping UdpListener.Receiver) -> Bool
	{
		gLogger.network("DiscoveryListener.start: Starting the listener")

		// If we are already in the correct state, return true
		if isActive
		{
			gLogger.network("DiscoveryListener.start:  > Starting broadcast listener that is already active")
			return true
		}

		// Save our connection receiver
		self.receiver = receiver

		if let interface = interface
		{
			gLogger.network("DiscoveryListener.start: Starting on interface \(interface.description), discovery port \(discoveryPort)")
		}
		else
		{
			gLogger.network("DiscoveryListener.start: Starting on all interfaces, discovery port \(discoveryPort)")
		}

		// Create a UDP listener
		listener = UdpListener(listenFrequencyMS: DiscoveryListener.kDefaultListenFrequencyMS)

		// Start listening for broadcast messages
		return listener!.start(interface: interface, port: discoveryPort, broadcastListener: !loopback, loopback: loopback, receiver: receiver)
	}

	/// Stops any active discovery
	///
	/// If discovery is not currently active, this method returns `true` immediately.
	///
	/// Returns `true` if the active discovery has been successfully terminated, `false` otherwise.
	public func stop() -> Bool
	{
		gLogger.network("DiscoveryListener.stop: Stopping the listener")

		if !isActive
		{
			gLogger.network("DiscoveryListener.stop:  > Stopping broadcast listener that's not active")
			return true
		}
		guard let listener = self.listener else { return true }

		// Ask the listener itself to stop
		if listener.stop()
		{
			// We are no longer active
			self.listener = nil
			return true
		}

		gLogger.error("DiscoveryListener.stop: Failed to stop the discovery listener")
		return false
	}
}
