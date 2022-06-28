//
//  Socket.swift
//  Minion
//
//  Created by Paul Nettle on 1/28/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// A Swift-native class for socket communications
public class Socket
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Total number of attempts to find an available random port
	private static let kMaxRandomPortAttempts = 100

	/// Minimum port address for random selection. This must be greater or equal to 1024 as those ports are reserved for system
	/// use. Must also be less than kMaxRandomPort.
	private static let kMinRandomPort: UInt16 = 1024

	/// Maximum port address for random port selection. Must be greater than kMinRandomPort.
	private static let kMaxRandomPort: UInt16 = 65535

	private static let kReceiveBufferSize: Int = 0xffff
	private static let kSendBufferSize: Int = 0xffff

	// -----------------------------------------------------------------------------------------------------------------------------
	// Local properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Our socket's file descriptor
	private(set) public var fd: Int32 = -1
	var domain: Int32 = 0
	#if os(Linux)
	var type: __socket_type = __socket_type(0)
	var proto: Int = 0
	#else
	var type: Int32 = 0
	var proto: Int32 = 0
	#endif

	/// Contains the port address the socket is bound to.
	///
	/// This value will be `nil` until a `bind` is called.
	///
	/// This is especially handy when a random port is chosen (by calling `bind()` with a port value of 0)
	private(set) public var boundPort: UInt16?

	// -----------------------------------------------------------------------------------------------------------------------------
	// Static methods for creating specific types of sockets
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns a UDP socket
	///
	/// Returns `nil` if the socket creation fails
	public static func createUdpSocket(enableBroadcast: Bool = false) -> Socket?
	{
#if os(Linux)
		guard let socket = Socket(domain: AF_INET, type: __socket_type(2), proto: IPPROTO_UDP) else { return nil }
#else
		guard let socket = Socket(domain: AF_INET, type: SOCK_DGRAM, proto: IPPROTO_UDP) else { return nil }
#endif

		if enableBroadcast && !socket.enableBroadcast()
		{
			_ = socket.close()
			gLogger.warn("Socket.createUdpSocket: Failed to create socket for broadcast (not enabled on socket)")
			return nil
		}

		// Set max receive buffer size
		if !socket.setReceiveBufferSize(bytes: kReceiveBufferSize)
		{
			gLogger.warn("Socket.createUdpSocket: Failed to set receive buffer size to maximum")
		}

		// Set max send buffer size
		if !socket.setSendBufferSize(bytes: kSendBufferSize)
		{
			gLogger.warn("Socket.createUdpSocket: Failed to set send buffer size to maximum")
		}

		return socket
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization and deinitialization
	// -----------------------------------------------------------------------------------------------------------------------------

	#if os(Linux)
	/// Initialize (and create) a socket
	public init?(domain: Int32, type: __socket_type, proto: Int)
	{
		self.domain = domain
		self.type = type
		self.proto = proto
		if !open(domain: domain, type: type, proto: proto) { return nil }
	}
	#else
	/// Initialize (and create) a socket
	public init?(domain: Int32, type: Int32, proto: Int32)
	{
		self.domain = domain
		self.type = type
		self.proto = proto
		if !open(domain: domain, type: type, proto: proto) { return nil }
	}
	#endif

	/// Automatically clean up the socket
	deinit
	{
		_ = close()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Higher level methods for setting specific socket options
	// -----------------------------------------------------------------------------------------------------------------------------

	#if os(Linux)
	/// Open (and create) a socket
	public func open(domain: Int32, type: __socket_type, proto: Int) -> Bool
	{
		// Close the socket (does nothing if already closed)
		_ = close()

		fd = socket(domain, Int32(type.rawValue), Int32(proto))
		if fd == -1
		{
			gLogger.error("Socket.open: Failed to create socket (errno[\(errno)]: \(String(cString: strerror(errno))))")
			return false
		}

		gLogger.network("Socket.open: Created socket (fd = \(fd))")
		return true
	}
	#else
	/// Open (and create) a socket
	public func open(domain: Int32, type: Int32, proto: Int32) -> Bool
	{
		// Close the socket (does nothing if already closed)
		_ = close()

		fd = socket(domain, type, proto)
		if fd == -1
		{
			gLogger.error("Socket.open: Failed to create socket (errno[\(errno)]: \(String(cString: strerror(errno))))")
			return false
		}

		gLogger.network("Socket.open: Created socket (fd = \(fd))")
		return true
	}
	#endif

	/// Close the socket
	///
	/// This method returns true if the socket is already closed
	public func close() -> Bool
	{
		if fd == -1 { return true }

		var closed = false
		#if os(Linux)
		closed = Glibc.close(fd) == 0
		#else
		closed = Darwin.close(fd) == 0
		#endif

		gLogger.network("Socket.close: Closing socket (fd = \(fd))")

		fd = -1

		if closed { return true }

		gLogger.error("Socket.close: Failed (errno[\(errno)]: \(String(cString: strerror(errno))))")
		return false
	}

	/// Enables SO_BROADCAST option on the socket
	public func enableBroadcast() -> Bool
	{
		return setOpt(level: SOL_SOCKET, name: SO_BROADCAST, value: 1)
	}

	/// Sets the socket options to bind this socket to a given interface index.
	///
	/// See `if_nametoindex()` or `Ipv4Interface.enumerateInterfaces()` for interface indices.
	public func bindToInterface(_ interface: Ipv4Interface) -> Bool
	{
		#if os(Linux)
			guard let name = interface.name else
			{
				gLogger.error("Socket.bindToDevice: Unable to bind to interface without a name")
				return false
			}
			return setOpt(level: SOL_SOCKET, name: SO_BINDTODEVICE, value: name)
		#else
			guard let index = interface.index else
			{
				gLogger.error("Socket.bindToDevice: Unable to bind to interface without an index")
				return false
			}
			return setOpt(level: Int32(IPPROTO_IP), name: IP_BOUND_IF, value: index)
		#endif
	}

	/// Sets the socket option for receive timeouts, specified in milliseconds
	public func setReceiveTimeout(timeoutMS: Int) -> Bool
	{
		var timeout = timeval()
		timeout.tv_sec = timeoutMS / 1000
		#if os(Linux)
			timeout.tv_usec = __suseconds_t(timeoutMS % 1000) * __suseconds_t(1000)
		#else
			timeout.tv_usec = __darwin_suseconds_t(timeoutMS % 1000) * __darwin_suseconds_t(1000)
		#endif
		return setOpt(level: SOL_SOCKET, name: SO_RCVTIMEO, value: timeout)
	}

	/// Sets the socket option for receive buffer size
	public func setReceiveBufferSize(bytes: Int) -> Bool
	{
		return setOpt(level: SOL_SOCKET, name: SO_RCVBUF, value: bytes)
	}

	/// Sets the socket option for send buffer size
	public func setSendBufferSize(bytes: Int) -> Bool
	{
		return setOpt(level: SOL_SOCKET, name: SO_SNDBUF, value: bytes)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// General implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Higher level interface for setting socket options (via `setsockopt`)
	///
	/// Returns true on success, otherwise false.
	public func setOpt<T>(level: Int32, name: Int32, value: T) -> Bool
	{
		if let strValue = value as? String
		{
			var tmp = strValue.cString(using: .ascii)!
			if setsockopt(fd, level, name, &tmp, UInt32(strlen(tmp))) != 0
			{
				gLogger.error("Socket.setOpt: Unable to set socket option (level:\(level),name:\(name)), errno[\(errno)]: \(String(cString: strerror(errno)))")
				return false
			}
		}
		else
		{
			var tmp = value
			if setsockopt(fd, level, name, &tmp, UInt32(MemoryLayout<T>.size)) != 0
			{
				gLogger.error("Socket.setOpt: Unable to set socket option (level:\(level),name:\(name)), errno[\(errno)]: \(String(cString: strerror(errno)))")
				return false
			}
		}

		return true
	}

	/// Bind a socket to an Ipv4SocketAddress
	///
	/// If the port is set to `0`, then a random (ephemeral) port is chosen. Use `boundPort` to determine the port that
	/// was bound.
	///
	/// Returns true on success, otherwise false.
	public func bind(to socketAddress: Ipv4SocketAddress) -> Bool
	{
		var saddrIn = sockaddr_in(socketAddress)
		let saddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

		// Search for a random available port?
		if saddrIn.sin_port == 0
		{
			assert(Socket.kMinRandomPort < Socket.kMaxRandomPort)
			assert(Socket.kMinRandomPort >= 1024)

			// Try our random attempts
			for _ in 0..<Socket.kMaxRandomPortAttempts
			{
				// Pick a random port
				guard let randomPort = Random.valueInRange(lower: UInt32(Socket.kMinRandomPort), upper: UInt32(Socket.kMaxRandomPort + 1)) else
				{
					continue
				}
				saddrIn.sin_port = in_port_t(randomPort)
				let portCopy = saddrIn.sin_port

				if withUnsafePointer(to: &saddrIn,
				{
					$0.withMemoryRebound(to: sockaddr.self, capacity: 1)
					{
						#if os(Linux)
							if Glibc.bind(fd, $0, saddrLen) == 0
							{
								boundPort = UInt16(bigEndian: portCopy)
								return true
							}
						#else
							if Darwin.bind(fd, $0, saddrLen) == 0
							{
								boundPort = UInt16(bigEndian: portCopy)
								return true
							}
						#endif

						return false
					}
				})
				{
					return true
				}
			}
		}
		else
		{
			let portCopy = saddrIn.sin_port
			return withUnsafePointer(to: &saddrIn,
			{
				$0.withMemoryRebound(to: sockaddr.self, capacity: 1)
				{
					#if os(Linux)
						if Glibc.bind(fd, $0, saddrLen) == 0
						{
							boundPort = UInt16(bigEndian: portCopy)
							return true
						}
					#else
						if Darwin.bind(fd, $0, saddrLen) == 0
						{
							boundPort = UInt16(bigEndian: portCopy)
							return true
						}
					#endif

					return false
				}
			})
		}

		return false
	}

	/// Sends data over UDP to a given address
	///
	/// Returns the number of bytes sent, otherwise -1 on error
	public func send(_ data: Data, to destAddr: Ipv4SocketAddress) -> Int
	{
		if gLogger.isSet(.Network)
		{
			let displayData = data.prefix(upTo: min(data.count, 64))
			gLogger.networkData(">> \(data.count.toString(3)) bytes >> \(destAddr) >> \(displayData.hexByteString(withSpaces: false))")
		}

		var dest = sockaddr(sockaddr_in(destAddr))
		let bytesSent = data.withUnsafeBytes
		{
			(_ src: UnsafeRawBufferPointer) -> Int in
			let ptr = src.baseAddress!.assumingMemoryBound(to: UInt8.self)
			return sendto(self.fd, ptr, data.count, 0, &dest, socklen_t(MemoryLayout<sockaddr_in>.size))
		}

		if bytesSent == -1
		{
			gLogger.error("Socket.send: Socket (fd = \(fd)) UDP send to \(destAddr.toString()) with data count of \(data.count) failed (errno[\(errno)]: \(String(cString: strerror(errno))))")
		}

		return bytesSent
	}

	/// Receives data from a given source address over UDP (in `srcAddr`)
	///
	/// Returns a tuple containing the data and sender, otherwise `nil` on error
	public func recv() -> (data: Data, sender: Ipv4SocketAddress)?
	{
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Socket.kReceiveBufferSize)
		defer { buffer.deallocate() }

		var sourceAddr = sockaddr_in()
		var sourceAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
		let bytesReceived = withUnsafeMutablePointer(to: &sourceAddr)
		{
			$0.withMemoryRebound(to: sockaddr.self, capacity: 1)
			{
				recvfrom(self.fd, buffer, Socket.kReceiveBufferSize, 0, $0, &sourceAddrLen)
			}
		}

		if bytesReceived == -1
		{
			if errno != EAGAIN
			{
				gLogger.error("Socket.recv: Socket (fd = \(fd)) UDP recv failed (errno[\(errno)]: \(String(cString: strerror(errno))))")
			}
			return nil
		}

		let sender = Ipv4SocketAddress(sourceAddr)
		let data = Data(bytes: buffer, count: bytesReceived)

		if gLogger.isSet(.Network)
		{
			let displayData = data.prefix(upTo: min(data.count, 64))
			gLogger.networkData("<< \(bytesReceived.toString(3)) bytes << \(sender.address.toIPAddress()):\(boundPort ?? 0) << \(displayData.hexByteString(withSpaces: false))")
		}

		return (data, sender)
	}
}
