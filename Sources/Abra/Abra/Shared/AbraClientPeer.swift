//
//  AbraClientPeer.swift
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
import AudioToolbox
#if os(iOS)
import SeerIOS
import MinionIOS
#else
import Seer
import Minion
#endif

/// `Peer` implementation specific to Abra
class AbraClientPeer: Peer
{
	/// The default broadcast discovery port this client will advertise to
	///
	/// We use the server's default so we match
	public static let kDefaultDiscoveryPort = Server.kDefaultDiscoveryPort

	/// The default control port that this client listens on... we add an arbitrary value to the server's control port so we
	/// are different (this only matters in test code where the same device runs a client and server simultaneously)
	public static let kDefaultControlPort = Server.kDefaultControlPort + 10

	/// The default watchdog timer period, in seconds.
	///
	/// If we don't receive any communication from the server in this period of time, we assume the connection is down and attempt
	/// to re-establish communication
	public static let kDefaultWatchdogFrequencySeconds: TimeInterval = Server.kPingFrequencySeconds * 3

	/// The local client object that will receive our data
	private var client: AbraApp

	/// The control port this client is configured to listen on
	private let controlPort: UInt16

	/// The UdpListener that we'll use to listen on our control channel
	private var controlChannelListener: UdpListener?

	/// The advertiser we'll use to discover the server
	private var advertiser: DiscoveryAdvertiser?

	/// Timer used to ensure connectivity with peer - if no data received in a period of time (see `kWatchdogFrequencySeconds`,
	/// then we assume the connection is dead, hangup and reestablish a connection
	private var watchdogTimer: Timer?

	/// The discovery port by which we advertise this client
	private let discoveryPort: UInt16

	/// Returns true if the peer is connected and listening
	public var isConnected: Bool
	{
		// If we're not listening, we're not connected
		if !(controlChannelListener?.isActive.value ?? false)
		{
			return false
		}

		// If we're advertising, we're not connected
		if advertiser?.isActive ?? false
		{
			return false
		}

		// If we don't have a socket address, we're not connected
		if nil == socketAddress
		{
			return false
		}

		return true
	}

	/// Initialize a `AbraClientPeer`
	public init?(client: AbraApp, discoveryPort: UInt16 = AbraClientPeer.kDefaultDiscoveryPort, controlPort: UInt16 = AbraClientPeer.kDefaultControlPort)
	{
		self.client = client
		self.discoveryPort = discoveryPort
		self.controlPort = controlPort

		// We init with a blank socket address for our peer since we don't know where the server is yet until we discover it
		super.init()

		gLogger.network("AbraClientPeer.init: Blank socket (fd = \(socket == nil ? "[nil]" : "\(socket!.fd)")) created and awaiting server discovery")
	}

	/// Starts the control channel listener
	///
	/// If the listener is already active, this method returns `true` immediately
	///
	/// Returns `true` on success, otherwise `false`
	public func startListener() -> Bool
	{
		// If we already have a control channel listener, just return true
		if nil != controlChannelListener { return true }

		gLogger.network("AbraClientPeer.startListener: Starting control channel listener for all interfaces on control port \(controlPort)")

		// Start our listener
		controlChannelListener = UdpListener()
		if !controlChannelListener!.start(port: controlPort, loopback: Preferences.shared.isLocalLoopback, receiver: controlPortReceiver)
		{
			gLogger.error("AbraClientPeer.startListener: Failed to start the control channel listener")
			controlChannelListener = nil
			return false
		}

		return true
	}

	/// Stops the control channel listener
	///
	/// If the control channel listener is already stopped, this method returns `true` immediately
	///
	/// Returns `true` on success, otherwise `false`
	public func stopListener() -> Bool
	{
		// If we are already stopped, just return true
		if nil == controlChannelListener { return true }

		gLogger.network("AbraClientPeer.stopListener: Stopping control channel listener")

		// Stop the control channel listener
		var success = true
		if !controlChannelListener!.stop()
		{
			gLogger.error("AbraClientPeer.stopListener: Failed to stop control channel listener")
			success = false
		}

		// Remove it
		controlChannelListener = nil

		return success
	}

	/// Expire our watchdog, which disconnects the client if we don't get a ping in enough time
	@objc private func onWatchdogExpiration(_: Timer)
	{
		gLogger.warn("AbraClientPeer.onWatchdogExpiration: Watchdog timer expired")

		onDisconnect(reason: "No device activity")
	}

	/// Start or restart a watchdog timer to ensure connectivity with the remote `Peer`
	///
	/// Call this method on initial connection and then each time data is received from the server to ensure connectivity. Each
	/// time this method is called, if a watchdog timer is currently running, it is first stopped (see `stopWatchdog()`) and a new
	/// timer is started.
	///
	/// If the timer ever expires, the connection is assumed to be disconnected and a new connection is established (see
	/// `onWatchdogExpiration()`)
	public func startWatchdog(period: TimeInterval = AbraClientPeer.kDefaultWatchdogFrequencySeconds)
	{
		DispatchQueue.main.async
		{
			if nil != self.watchdogTimer
			{
				//gLogger.debug("AbraClientPeer.startWatchdog: Restarting the watchdog timer")
				self.watchdogTimer?.invalidate()
				self.watchdogTimer = nil
			}
			else
			{
				gLogger.network("AbraClientPeer.startWatchdog: Starting the watchdog timer")
			}

			// Start our watchdog timer
			if #available(iOS 10.0, *)
			{
				self.watchdogTimer = Timer.scheduledTimer(withTimeInterval: period, repeats: false, block: self.onWatchdogExpiration)
			}
			else
			{
				self.watchdogTimer = Timer.scheduledTimer(timeInterval: period, target: self, selector: #selector(AbraClientPeer.onWatchdogExpiration(_:)), userInfo: nil, repeats: false)
			}
		}
	}

	/// Stop the watchdog timer
	///
	/// This should be done whenever we are disconnected (since we won't be getting pings)
	public func stopWatchdog()
	{
		if nil == watchdogTimer { return }

		gLogger.network("AbraClientPeer.stopWatchdog: Stopping the watchdog timer")

		DispatchQueue.main.async
		{
			// Stop the watchdog timer
			self.watchdogTimer?.invalidate()
			self.watchdogTimer = nil
		}
	}

	/// Starts the broadcast advertiser
	///
	/// If the advertiser is already active, this method returns `true` immediately
	///
	/// Returns `true` on success, otherwise `false`
	public func startAdvertiser() -> Bool
	{
		// If we already have a control channel listener, just return true
		if nil != advertiser { return true }

		gLogger.network("AbraClientPeer.startAdvertiser: Starting the broadcast advertiser on discovery port \(discoveryPort) and control port \(controlPort)")

		advertiser = DiscoveryAdvertiser()
		if !advertiser!.start(discoveryPort: discoveryPort, clientControlPort: controlPort, loopback: Preferences.shared.isLocalLoopback)
		{
			gLogger.error("AbraClientPeer.startAdvertiser: Failed to start the broadcast advertiser")
			advertiser = nil
			return false
		}

		client.setDisconnected()

		return true
	}

	/// Stops the broadcast advertiser
	///
	/// If the advertiser is already stopped, this method returns `true` immediately
	///
	/// Returns `true` on success, otherwise `false`
	public func stopAdvertiser() -> Bool
	{
		// If we are already stopped, just return true
		guard let advertiser = advertiser else { return true }

		gLogger.network("AbraClientPeer.stopAdvertiser: Stopping the broadcast advertiser")

		// Stop the control broadcast advertiser
		var success = true
		if !advertiser.stop()
		{
			gLogger.error("AbraClientPeer.stopAdvertiser: Failed to stop the broadcast advertiser")
			success = false
		}

		client.setConnected()

		// Remove it
		self.advertiser = nil

		return success
	}

	/// Starts the broadcast advertiser and control channel listener
	public func start() -> Bool
	{
		var success = true
		if !startListener()
		{
			gLogger.error("AbraClientPeer.start: Failed start the control channel listener")
			success = false
		}

		if !startAdvertiser()
		{
			gLogger.error("AbraClientPeer.start: Failed start the broadcast advertiser")
			_ = stopListener()
			success = false
		}

		return success
	}

	/// Disconnects from the client, terminates the control channel listener and stops the broadcast advertiser
	override public func hangup() -> Bool
	{
		// Stop the watchdog timer
		stopWatchdog()

		var success = true
		if !stopAdvertiser()
		{
			gLogger.error("AbraClientPeer.hangup: Failed to stop the broadcast advertiser")
			success = false
		}

		if !stopListener()
		{
			gLogger.error("AbraClientPeer.hangup: Failed to stop the control channel listener")
			success = false
		}

		// The super sends the disconnect message
		if !super.hangup()
		{
			success = false
		}

		return success
	}

	/// Hanlde client connections
	///
	/// This stops the advertiser starts the watchdog
	override func onClientConnect(from socketAddress: Ipv4SocketAddress)
	{
		// If the connection isn't allowed, bail now
		if !client.allowConnection(from: socketAddress) { return }

		super.onClientConnect(from: socketAddress)

		gLogger.info("AbraClientPeer.onClientConnect: Connected to \(socketAddress.description)")

		// Stop advertising; we no longer need to find a server, we have one
		if !stopAdvertiser()
		{
			gLogger.error("AbraClientPeer.onClientConnect: Failed to stop the client advertiser")
		}
		else
		{
			gLogger.network("AbraClientPeer.onClientConnect: Client advertiser stopped")
		}

		// Start our watchdog to monitor this connection
		startWatchdog()

		let configValueRequest = ConfigValueListMessage()

		// Request our full list of config values
		if self.send(configValueRequest)
		{
			gLogger.network("AbraClientPeer.onClientConnect: Requested config value list")
		}
		else
		{
			gLogger.warn("AbraClientPeer.onClientConnect: Failed to request config value list")
		}
	}

	/// Handle client disconnects
	///
	/// This stops the watchdog and starts the advertiser.
	override func onDisconnect(reason: String?)
	{
		gLogger.info("AbraClientPeer.onDisconnect: Disconnection from \(socketAddress?.description ?? "[none]") with reason: \(reason ?? "[none given]")")

		super.onDisconnect(reason: reason)

		client.setDisconnected()

		// We no longer need our watchdog timer
		stopWatchdog()

		// Restart the advertiser
		gLogger.network("AbraClientPeer.onDisconnect: Restarting broadcast advertiser")
		if !startAdvertiser()
		{
			gLogger.error("AbraClientPeer.onDisconnect: Failed to start the client advertiser")
		}
		else
		{
			gLogger.network("AbraClientPeer.onDisconnect: Client advertiser started")
		}
	}

	/// Handle and respond to pings
	override public func onPing()
	{
		guard let socketAddress = self.socketAddress else
		{
			gLogger.error("Peer.onPing: AbraClientPeer received ping, but does not appear to be connected")
			return
		}

		guard let socket = self.socket else
		{
			gLogger.error("Peer.onPing: AbraClientPeer received ping, but does not appear to be connected (no socket)")
			return
		}

		// Respond to the ping
		guard let payload: Packet.Payload = PingAckMessage().getPayload() else
		{
			gLogger.error("Peer.onPing: Failed to create PingAckMessage payload")
			return
		}

		guard let packet = Packet.construct(fromPayload: payload) else
		{
			gLogger.error("Peer.onPing: Failed to construct packet")
			return
		}

		gLogger.debug("Peer.onPayload: Sending Ping ACK message to peer")

		if !packet.send(to: socketAddress, over: socket)
		{
			gLogger.error("Peer.onPing: Failed to send packet")
		}
	}

	/// Handle incomind data
	override func onPayload( from peerSourceAddress: Ipv4SocketAddress, payload: Packet.Payload) -> Bool
	{
		// If we're local, then ensure we only ever talk to a local server
		if Preferences.shared.localServerEnabled
		{
			if socketAddress != nil && peerSourceAddress.address != socketAddress!.address
			{
				// We've handled this by dropping it on the floor
				return true
			}
		}

		// Restart our watchdog timer
		startWatchdog()

		// See if the super can handle the payload
		if super.onPayload(from: peerSourceAddress, payload: payload) { return true }

		switch payload.info.id
		{
			case ScanReportMessage.payloadId:
				gLogger.networkData("AbraClientPeer.onPayload: [\(id)] received [ScanReportMessage] from source address \(peerSourceAddress)")
				if let message = ScanReportMessage.decode(from: payload.data)
				{
					onScanReport(message: message)
				}
				else
				{
					gLogger.error("AbraClientPeer.onPayload[ScanReportMessage]: Failed to decode message")
				}

			case ScanMetadataMessage.payloadId:
				gLogger.networkData("AbraClientPeer.onPayload: [\(id)] received [ScanMetadataMessage] from source address \(peerSourceAddress)")
				if let message = ScanMetadataMessage.decode(from: payload.data)
				{
					onScanMetadata(message: message)
				}
				else
				{
					gLogger.error("AbraClientPeer.onPayload[ScanMetadataMessage]: Failed to decode message")
				}

			case PerformanceStatsMessage.payloadId:
				gLogger.networkData("AbraClientPeer.onPayload: [\(id)] received [PerformanceStatsMessage] from source address \(peerSourceAddress)")
				if let message = PerformanceStatsMessage.decode(from: payload.data)
				{
					onPerformanceStats(message: message)
				}
				else
				{
					gLogger.error("AbraClientPeer.onPayload[ScanReportMessage]: Failed to decode message")
				}

			case ViewportMessage.payloadId:
				gLogger.networkData("AbraClientPeer.onPayload: [\(id)] received [ViewportMessage] from source address \(peerSourceAddress)")
				if let message = ViewportMessage.decode(from: payload.data)
				{
					onViewport(message: message)
				}
				else
				{
					gLogger.error("AbraClientPeer.onPayload[ViewportMessage]: Failed to decode viewport message")
				}

			case ServerConnectMessage.payloadId:
				gLogger.networkData("AbraClientPeer.onPayload: [\(id)] received [ServerConnectMessage] from source address \(peerSourceAddress)")
				if let message = ServerConnectMessage.decode(from: payload.data)
				{
					onServerConnect(message: message)
				}
				else
				{
					gLogger.error("AbraClientPeer.onPayload[ServerConnectMessage]: Failed to decode server info")
				}

			case TriggerVibrationMessage.payloadId:
				gLogger.networkData("AbraClientPeer.onPayload: [\(id)] received [TriggerVibrationMessage] from source address \(peerSourceAddress)")
				gLogger.info("AbraClientPeer.onPayload[TriggerVibrationMessage]: Vibrating!")
				AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))

			case ConfigValueListMessage.payloadId:
				gLogger.networkData("AbraClientPeer.onPayload: [\(id)] received [ConfigValueListMessage] from source address \(peerSourceAddress)")
				if let message = ConfigValueListMessage.decode(from: payload.data)
				{
					gLogger.info("AbraClientPeer.onPayload[ConfigValueListMessage]: Assigning \(message.configValues.count) config values")
					ServerConfig.shared.populate(message.configValues)
				}
				else
				{
					gLogger.error("AbraClientPeer.onPayload[ConfigValueListMessage]: Failed to decode message")
				}

			case ConfigValueMessage.payloadId:
				gLogger.networkData("AbraClientPeer.onPayload: [\(id)] received [ConfigValueMessage] from source address \(peerSourceAddress)")
				if let message = ConfigValueMessage.decode(from: payload.data)
				{
					gLogger.info("AbraClientPeer.onPayload[ConfigValueMessage]: Assigning config value '\(message.name)'")
					ServerConfig.shared.set(message: message)
				}
				else
				{
					gLogger.error("AbraClientPeer.onPayload[ConfigValueMessage]: Failed to decode message")
				}

			default:
				// We don't handle this message, pass it along
				gLogger.warn("AbraClientPeer.onPayload: [\(id)] received unknown message: \(payload.info.id) from source address \(peerSourceAddress)")
				return false
		}

		return true
	}

	/// Handle incoming scan reports
	private func onScanReport(message: ScanReportMessage)
	{
		client.processReport(message)
	}

	/// Handle incoming scan report metadatas
	private func onScanMetadata(message: ScanMetadataMessage)
	{
		client.processMetadata(message)
	}

	/// Handle incoming performance stats
	private func onPerformanceStats(message: PerformanceStatsMessage)
	{
		client.processPerformanceStats(message)
	}

	/// Handle incoming viewport updates
	private func onViewport(message: ViewportMessage)
	{
		client.processViewport(message)
	}

	/// Handle incoming server connections
	private func onServerConnect(message: ServerConnectMessage)
	{
		client.setConnected(versions: message.versions)
	}

	/// When receiving data on our control port, this is where it comes in - we simply redirect it over to `onPayload`
	private func controlPortReceiver(sourceAddress: Ipv4SocketAddress, payload: Packet.Payload) -> Bool
	{
		if !onPayload(from: sourceAddress, payload: payload)
		{
			gLogger.error("Unknown packet: \(payload.info.id)")
		}

		return true
	}
}
