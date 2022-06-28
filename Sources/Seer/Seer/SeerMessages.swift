//
//  SeerMessages.swift
//  Seer
//
//  Created by Paul Nettle on 2/20/18.
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

/// A report of ordered cards
///
/// SERVER -> CLIENT
public struct ScanReportMessage: NetMessage
{
	/// The timestamp when this report was generated, in seconds
	private var timestampSeconds: TimeInterval = 0

	/// The Payload Id for this message
	public static var payloadId: String { return "300AA566-8211-44DE-88C6-FCAF26964C21" }

	/// Is this report a high-confidence report?
	public var highConfidence = false

	/// The deck format UID for the indices stored in this report
	public var formatId: UInt32 = 0

	/// The confidence factor for this report
	public var confidenceFactor: UInt8 = 0

	/// The indices for this report
	public var indices = [UInt8]()

	/// The robustness for each index for this report
	public var robustness = [UInt8]()

	/// The number of reports we've had
	public var reportCount: UInt32 = 0

	/// We need a public initializer
	public init()
	{
	}

	public mutating func update(highConfidence: Bool, formatId: UInt32, confidenceFactor: UInt8, indices: [UInt8], robustness: [UInt8])
	{
		reportCount += 1

		self.highConfidence = highConfidence
		self.formatId = formatId
		self.confidenceFactor = confidenceFactor
		self.indices = indices
		self.robustness = robustness
		self.timestampSeconds = Date.timeIntervalSinceReferenceDate
	}

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !highConfidence.encode(into: &data) { return false }
		if !formatId.encode(into: &data) { return false }
		if !confidenceFactor.encode(into: &data) { return false }
		if !indices.encode(into: &data) { return false }
		if !robustness.encode(into: &data) { return false }
		if !reportCount.encode(into: &data) { return false }
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> ScanReportMessage?
	{
		guard let highConfidence = Bool.decode(from: data, consumed: &consumed) else { return nil }
		guard let formatId = UInt32.decode(from: data, consumed: &consumed) else { return nil }
		guard let confidenceFactor = UInt8.decode(from: data, consumed: &consumed) else { return nil }
		guard let indices = [UInt8].decode(from: data, consumed: &consumed) else { return nil }
		guard let robustness = [UInt8].decode(from: data, consumed: &consumed) else { return nil }
		guard let reportCount = UInt32.decode(from: data, consumed: &consumed) else { return nil }

		var message = ScanReportMessage()
		message.highConfidence = highConfidence
		message.formatId = formatId
		message.confidenceFactor = confidenceFactor
		message.indices = indices
		message.robustness = robustness
		message.reportCount = reportCount
		return message
	}
}

/// A report of scanning metadata
///
/// SERVER -> CLIENT
public struct ScanMetadataMessage: NetMessage
{
	/// The Payload Id for this message
	public static var payloadId: String { return "FE617004-ACE6-4D92-9F86-8C67751A1C39" }

	/// The total number of frames scanned
	public var frameCount: UInt32 = 0

	/// Is this report a high-confidence report?
	public var status: String = ""

	private init()
	{
	}

	/// We need a public initializer
	public init(frameCount: UInt32, status: String)
	{
		var thisStatus = status

		if let range = thisStatus.range(of: "[")
		{
			thisStatus = String(thisStatus[thisStatus.startIndex..<range.lowerBound])
		}

		switch thisStatus
		{
			case "NotSharp":				thisStatus = "NS"
			case "Too small":				thisStatus = "TS"
			case "Not found":				thisStatus = "NF"
			case "TooFew":					thisStatus = "TF"
			case "Inconclusive":			thisStatus = "IN"
			case "NotEnoughHistory":		thisStatus = "NH"
			case "NotEnoughConfidence":		thisStatus = "NC"
			case "ResultLowConfidence":		thisStatus = "RL"
			case "ResultHighConfidence":	thisStatus = "RH"
			default:						thisStatus = "GF"
		}

		self.frameCount = frameCount
		self.status = thisStatus
	}

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !frameCount.encode(into: &data) { return false }
		if !status.encode(into: &data) { return false }
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> ScanMetadataMessage?
	{
		guard let frameCount = UInt32.decode(from: data, consumed: &consumed) else { return nil }
		guard let status = String.decode(from: data, consumed: &consumed) else { return nil }

		var message = ScanMetadataMessage()
		message.frameCount = frameCount
		message.status = status
		return message
	}
}

/// A report of performance statistics
///
/// NOTE: Be sure to re-use this object over time to gather proper full frame times. These are tracked using absolute time from
///       `update` call to `update` call.
///
/// SERVER -> CLIENT
public struct PerformanceStatsMessage: NetMessage
{
	/// The Payload Id for this message
	public static var payloadId: String { return "6359b87e-f806-46b6-836e-091fee8a68c3" }

	/// The time required to scan the deck
	public var scanMS: Real = 0

	/// The time to process a complete frame  (including capture/decode, debug overhead, etc.)
	public var fullFrameMS: Real = 0

	/// The time from complete frame to complete frame (used for FPS calculations)
	public var frameToFrameTimeMS: Real = 0

	/// Local variable used to track times between calls to `update`
	private var lastFrameToFrameTimeMS: Time = 0

	/// We need a public initializer
	public init()
	{
	}

	/// Populates the performance stats for the current frame
	///
	/// This should only be called from the server-side
	public mutating func update()
	{
		let curTimeMS = PausableTime.getTimeMS()
		if lastFrameToFrameTimeMS != 0 { frameToFrameTimeMS = Real(curTimeMS - lastFrameToFrameTimeMS) }
		lastFrameToFrameTimeMS = curTimeMS

		scanMS = Real(PerfTimer.getStat(name: "Scan")?.lastMS ?? 0)
		fullFrameMS = Real(PerfTimer.getStat(name: "Full frame")?.lastMS ?? 0)
	}

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !scanMS.encode(into: &data) { return false }
		if !fullFrameMS.encode(into: &data) { return false }
		if !frameToFrameTimeMS.encode(into: &data) { return false }
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> PerformanceStatsMessage?
	{
		guard let scanMS = Real.decode(from: data, consumed: &consumed) else { return nil }
		guard let fullFrameMS = Real.decode(from: data, consumed: &consumed) else { return nil }
		guard let frameToFrameTimeMS = Real.decode(from: data, consumed: &consumed) else { return nil }

		var stats = PerformanceStatsMessage()
		stats.scanMS = scanMS
		stats.fullFrameMS = fullFrameMS
		stats.frameToFrameTimeMS = frameToFrameTimeMS
		return stats
	}
}

/// A viewport (image view)
///
/// SERVER -> CLIENT
public struct ViewportMessage: NetMessage
{
	public enum ViewportType: UInt8
	{
		case LumaResampledToViewportSize = 0
		case LumaCenterViewportRect

		public static func fromUInt8(_ value: UInt8) -> ViewportType
		{
			return ViewportType(rawValue: value) ?? .LumaResampledToViewportSize
		}
	}

	/// The Payload Id for this message
	public static var payloadId: String { return "BC2E0EF1-D6DD-44B4-93AC-CDFFC96F0FC3" }

	/// Viewport type
	public var viewportType: ViewportType = .LumaResampledToViewportSize

	/// The width of the image
	public var width: UInt16 = 0

	/// The height of the image
	public var height: UInt16 = 0

	/// The pixels of the image
	public var buffer: Data = Data()

	private init()
	{
	}

	/// We need a public initializer
	public init(viewportType: ViewportType, width: UInt16, height: UInt16, buffer: Data)
	{
		self.viewportType = viewportType
		self.width = width
		self.height = height
		self.buffer = buffer
	}

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !viewportType.rawValue.encode(into: &data) { return false }
		if !width.encode(into: &data) { return false }
		if !height.encode(into: &data) { return false }
		if !buffer.encode(into: &data) { return false }
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> ViewportMessage?
	{
		guard let viewportType = UInt8.decode(from: data, consumed: &consumed) else { return nil }
		guard let width = UInt16.decode(from: data, consumed: &consumed) else { return nil }
		guard let height = UInt16.decode(from: data, consumed: &consumed) else { return nil }
		guard let buffer = Data.decode(from: data, consumed: &consumed) else { return nil }

		var message = ViewportMessage()
		message.viewportType = ViewportType.fromUInt8(viewportType)
		message.width = width
		message.height = height
		message.buffer = buffer
		return message
	}
}

/// A command
///
/// CLIENT -> SERVER
public struct CommandMessage: NetMessage
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Global constants
	// -----------------------------------------------------------------------------------------------------------------------------

	public static let kShutdown = "shutdown"
	public static let kReboot = "reboot"
	public static let kCheckForUpdates = "checkForUpdates"

	// -----------------------------------------------------------------------------------------------------------------------------
	// Global constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The Payload Id for this message
	public static var payloadId: String { return "D4C60CEC-2115-46DA-BCDE-071CF2DFB4FE" }

	/// The command name
	public var command: String = ""

	/// Parameters for the command
	public var parameters = [String]()

	private init()
	{
	}

	/// We need a public initializer
	public init(command: String, parameters: [String])
	{
		self.command = command
		self.parameters = parameters
	}

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !command.encode(into: &data) { return false }
		if !parameters.encode(into: &data) { return false }
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> CommandMessage?
	{
		guard let command = String.decode(from: data, consumed: &consumed) else { return nil }
		guard let parameters = [String].decode(from: data, consumed: &consumed) else { return nil }

		var message = CommandMessage()
		message.command = command
		message.parameters = parameters
		return message
	}
}

/// A ConfigValueList message
///
/// Sent by the client to request a list of config value names
/// Sent by the server containing as a response containing a list of config value names
public struct ConfigValueListMessage: NetMessage
{
	public struct ConfigValue: Codable
	{
		public private(set) var category: String
		public private(set) var name: String
		public private(set) var type: Config.ValueType
		public private(set) var value: Any
		public private(set) var description: String

		public var fullName: String
		{
			return "\(category).\(name)"
		}

		public init?(name: String, type: Config.ValueType, value: Any, description: String)
		{
			let parts = name.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)

			// If you hit this assert, your config value has more than one '.' separator (this is not allowed)
			assert(parts.count == 2)
			if parts.count != 2 { return nil }
			self.category = String(parts[0])
			self.name = String(parts[1])
			self.type = type
			self.value = value
			self.description = description
		}

		public init(category: String, name: String, type: Config.ValueType, value: Any, description: String)
		{
			self.category = category
			self.name = name
			self.type = type
			self.value = value
			self.description = description
		}

		/// Update the value for this config value
		public mutating func updateValue(_ newValue: Any)
		{
			value = newValue
		}

		/// Encodable conformance
		public func encode(into data: inout Data) -> Bool
		{
			if !category.encode(into: &data) { return false }
			if !name.encode(into: &data) { return false }
			if !type.rawValue.encode(into: &data) { return false }
			switch type
			{
				case .String:
					guard let v = value as? String else
					{
						gLogger.error("Config value '\(name)' does not convert to String")
						return false
					}
					if !v.encode(into: &data)
					{
						gLogger.error("Config value '\(name)' failed to encode element")
						return false
					}
				case .StringMap:
					guard let v = value as? [String: String] else
					{
						gLogger.error("Config value '\(name)' does not convert to [String: String]")
						return false
					}
					if !v.encode(into: &data)
					{
						gLogger.error("Config value '\(name)' failed to encode element")
						return false
					}
				case .Path:
					guard let v = value as? PathString else
					{
						gLogger.error("Config value '\(name)' does not convert to Path")
						return false
					}
					if !v.encode(into: &data)
					{
						gLogger.error("Config value '\(name)' failed to encode element")
						return false
					}
				case .PathArray:
					guard let v = value as? [PathString] else
					{
						gLogger.error("Config value '\(name)' does not convert to [Path]")
						return false
					}
					if !v.encode(into: &data)
					{
						gLogger.error("Config value '\(name)' failed to encode element")
						return false
					}
				case .CodeDefinition:
					guard let v = value as? String else
					{
						gLogger.error("Config value '\(name)' does not convert to String")
						return false
					}
					if !v.encode(into: &data)
					{
						gLogger.error("Config value '\(name)' failed to encode element")
						return false
					}
				case .Boolean:
					guard let v = value as? Bool else
					{
						gLogger.error("Config value '\(name)' does not convert to Bool")
						return false
					}
					if !v.encode(into: &data)
					{
						gLogger.error("Config value '\(name)' failed to encode element")
						return false
					}
				case .Integer:
					guard let v = value as? Int else
					{
						gLogger.error("Config value '\(name)' does not convert to Int")
						return false
					}
					if !Int64(v).encode(into: &data) { return false }
				case .FixedPoint:
					guard let v = value as? Double else
					{
						gLogger.error("Config value '\(name)' does not convert to Double")
						return false
					}
					if !v.encode(into: &data)
					{
						gLogger.error("Config value '\(name)' failed to encode element")
						return false
					}
				case .Real:
					guard let v = value as? Double else
					{
						gLogger.error("Config value '\(name)' does not convert to Double")
						return false
					}
					if !v.encode(into: &data)
					{
						gLogger.error("Config value '\(name)' failed to encode element")
						return false
					}
				case .RollValue:
					guard let v = value as? Double else
					{
						gLogger.error("Config value '\(name)' does not convert to Double")
						return false
					}
					if !v.encode(into: &data)
					{
						gLogger.error("Config value '\(name)' failed to encode element")
						return false
					}
				case .Time:
					guard let v = value as? Double else
					{
						gLogger.error("Config value '\(name)' does not convert to Double")
						return false
					}
					if !v.encode(into: &data)
					{
						gLogger.error("Config value '\(name)' failed to encode element")
						return false
					}
			}
			if !description.encode(into: &data) { return false }
			return true
		}

		/// Decodable conformance
		public static func decode(from data: Data, consumed: inout Int) -> ConfigValue?
		{
			guard let category = String.decode(from: data, consumed: &consumed) else { return nil }
			guard let name = String.decode(from: data, consumed: &consumed) else { return nil }
			guard let rawType = Config.ValueType.RawValue.decode(from: data, consumed: &consumed) else { return nil }
			guard let type = Config.ValueType(rawValue: rawType) else { return nil }
			var value: Any?
			switch type
			{
				case .String: value = String.decode(from: data, consumed: &consumed)
				case .StringMap: value = [String: String].decode(from: data, consumed: &consumed)
				case .Path: value = PathString.decode(from: data, consumed: &consumed)
				case .PathArray: value = [PathString].decode(from: data, consumed: &consumed)
				case .CodeDefinition:
					guard let name = String.decode(from: data, consumed: &consumed) else { return nil }
					guard let codeDefinition = CodeDefinition.findCodeDefinition(byName: name) else
					{
						gLogger.error("Unable to locate code definition named '\(name)'")
						return nil
					}
					value = codeDefinition
				case .Boolean: value = Bool.decode(from: data, consumed: &consumed)
				case .Integer:
					guard let int64 = Int64.decode(from: data, consumed: &consumed) else { return nil }
					value = Int(int64)
				case .FixedPoint:
					guard let doubleValue = Double.decode(from: data, consumed: &consumed) else { return nil }
					value = FixedPoint(doubleValue)
				case .Real:
					guard let realValue = Double.decode(from: data, consumed: &consumed) else { return nil }
					value = Real(realValue)
				case .RollValue:
					guard let rollValue = Double.decode(from: data, consumed: &consumed) else { return nil }
					value = RollValue(rollValue)
				case .Time:
					guard let timeValue = Double.decode(from: data, consumed: &consumed) else { return nil }
					value = Time(timeValue)
			}
			if value == nil { return nil }
			guard let description = String.decode(from: data, consumed: &consumed) else { return nil }

			return ConfigValue(category: category, name: name, type: type, value: value!, description: description)
		}
	}

	/// The Payload Id for this message
	public static var payloadId: String { return "9F02B8F2-6A80-4DFF-BC6A-E22BF2ED1A91" }

	/// Viewport type
	public var configValues = [ConfigValue]()

	public init()
	{
	}

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !UInt16(configValues.count).encode(into: &data) { return false }

		for configValue in configValues
		{
			if !configValue.encode(into: &data)
			{
				gLogger.error("Unable to encode ConfigValue '\(configValue.name)'")
				return false
			}
		}
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> ConfigValueListMessage?
	{
		guard let count = UInt16.decode(from: data, consumed: &consumed) else { return nil }
		var message = ConfigValueListMessage()
		for _ in 0..<count
		{
			guard let value = ConfigValueListMessage.ConfigValue.decode(from: data, consumed: &consumed) else { return nil }
			message.configValues.append(value)
		}
		return message
	}
}

/// Sets or gets a config value (depending on the direction of the message)
///
/// SERVER <-> CLIENT
///
/// When sent from the server, it provides the value for the named config value.
/// When sent from the client, it represents a new value for the named config value.
public struct ConfigValueMessage: NetMessage
{
	/// The Payload Id for this message
	public static var payloadId: String { return "AA97D671-37DF-4A43-ABC1-759FFBCCBE73" }

	/// The config value name
	public var name: String = ""

	/// The type of value
	public var valueType: Config.ValueType = .String

	/// The string, if present
	public var stringValue: String?

	/// The path, if present
	public var pathValue: PathString?

	/// The path, if present
	public var pathArrayValue: [PathString]?

	/// The string, if present
	public var codeDefinitionValue: CodeDefinition?

	/// The string map, if present
	public var stringMapValue: [String: String]?

	/// The boolean, if present
	public var booleanValue: Bool?

	/// The integer, if present
	public var integerValue: Int?

	/// The fixed point, if present
	public var fixedPointValue: FixedPoint?

	/// The Real, if present
	public var realValue: Real?

	/// The RollValue, if present
	public var rollValue: RollValue?

	/// The Time, if present
	public var timeValue: Time?

	private init()
	{
	}

	public init(name: String, withString value: String)
	{
		self.name = name
		self.valueType = .String
		self.stringValue = value
	}

	public init(name: String, withStringMap value: [String: String])
	{
		self.name = name
		self.valueType = .StringMap
		self.stringMapValue = value
	}

	public init(name: String, withPath value: PathString)
	{
		self.name = name
		self.valueType = .Path
		self.pathValue = value
	}

	public init(name: String, withPathArray value: [PathString])
	{
		self.name = name
		self.valueType = .PathArray
		self.pathArrayValue = value
	}

	public init(name: String, withCodeDefinition value: CodeDefinition)
	{
		self.name = name
		self.valueType = .CodeDefinition
		self.codeDefinitionValue = value
	}

	public init(name: String, withBoolean value: Bool)
	{
		self.name = name
		self.valueType = .Boolean
		self.booleanValue = value
	}

	public init(name: String, withInteger value: Int)
	{
		self.name = name
		self.valueType = .Integer
		self.integerValue = value
	}

	public init(name: String, withFixedPoint value: FixedPoint)
	{
		self.name = name
		self.valueType = .FixedPoint
		self.fixedPointValue = value
	}

	public init(name: String, withReal value: Real)
	{
		self.name = name
		self.valueType = .Real
		self.realValue = value
	}

	public init(name: String, withRollValue value: RollValue)
	{
		self.name = name
		self.valueType = .RollValue
		self.rollValue = value
	}

	public init(name: String, withTime value: Time)
	{
		self.name = name
		self.valueType = .Time
		self.timeValue = value
	}

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !name.encode(into: &data) { return false }
		if !valueType.rawValue.encode(into: &data) { return false }

		// Encode the value of the appropriate type
		switch valueType
		{
			case .String:
				if !(stringValue?.encode(into: &data) ?? false) { return false }
			case .Path:
				if !(pathValue?.encode(into: &data) ?? false) { return false }
			case .CodeDefinition:
				if !(codeDefinitionValue?.encode(into: &data) ?? false) { return false }
			case .StringMap:
				if !(stringMapValue?.encode(into: &data) ?? false) { return false }
			case .PathArray:
				if !(pathArrayValue?.encode(into: &data) ?? false) { return false }
			case .Boolean:
				if !(booleanValue?.encode(into: &data) ?? false) { return false }
			case .Integer:
				if nil == integerValue { return false }
				if !Int64(integerValue!).encode(into: &data) { return false }
			case .FixedPoint:
				if !(fixedPointValue?.encode(into: &data) ?? false) { return false }
			case .Real:
				if !(realValue?.encode(into: &data) ?? false) { return false }
			case .RollValue:
				if !(rollValue?.encode(into: &data) ?? false) { return false }
			case .Time:
				if !(timeValue?.encode(into: &data) ?? false) { return false }
		}

		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> ConfigValueMessage?
	{
		guard let name = String.decode(from: data, consumed: &consumed) else { return nil }
		guard let valueTypeRawValue = Config.ValueType.RawValue.decode(from: data, consumed: &consumed) else { return nil }
		guard let valueType = Config.ValueType(rawValue: valueTypeRawValue) else { return nil }

		var message = ConfigValueMessage()
		message.name = name
		message.valueType = valueType

		// Decode the value of the appropriate type
		switch valueType
		{
			case .String:
				guard let value = String.decode(from: data, consumed: &consumed) else { return nil }
				message.stringValue = value
			case .Path:
				guard let value = PathString.decode(from: data, consumed: &consumed) else { return nil }
				message.pathValue = value
			case .CodeDefinition:
				guard let value = CodeDefinition.decode(from: data, consumed: &consumed) else { return nil }
				message.codeDefinitionValue = value
			case .StringMap:
				guard let value = [String: String].decode(from: data, consumed: &consumed) else { return nil }
				message.stringMapValue = value
			case .PathArray:
				guard let value = [PathString].decode(from: data, consumed: &consumed) else { return nil }
				message.pathArrayValue = value
			case .Boolean:
				guard let value = Bool.decode(from: data, consumed: &consumed) else { return nil }
				message.booleanValue = value
			case .Integer:
				guard let value = Int64.decode(from: data, consumed: &consumed) else { return nil }
				message.integerValue = Int(value)
			case .FixedPoint:
				guard let value = FixedPoint.decode(from: data, consumed: &consumed) else { return nil }
				message.fixedPointValue = value
			case .Real:
				guard let value = Real.decode(from: data, consumed: &consumed) else { return nil }
				message.realValue = value
			case .RollValue:
				guard let value = RollValue.decode(from: data, consumed: &consumed) else { return nil }
				message.rollValue = value
			case .Time:
				guard let value = Time.decode(from: data, consumed: &consumed) else { return nil }
				message.timeValue = value
		}

		return message
	}
}

/// A ServerConnect message
///
/// Sent from servers to clients on the client's control port
public struct ServerConnectMessage: NetMessage
{
	/// The Payload Id for this message
	public static var payloadId: String { return "05AA3FEF-83D6-4D22-A8A7-BB254652879B" }

	/// A map of [name:version], such as ["minion":"1234:master:m"]
	public let versions: [String: String]

	public init(versions: [String: String])
	{
		self.versions = versions
	}

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !UInt16(versions.count).encode(into: &data) { return false }

		for key in versions.keys
		{
			if !key.encode(into: &data) { return false }
			if !versions[key]!.encode(into: &data) { return false }
		}
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> ServerConnectMessage?
	{
		var versions = [String: String]()
		guard let count = UInt16.decode(from: data, consumed: &consumed) else { return nil }
		for _ in 0..<count
		{
			guard let key = String.decode(from: data, consumed: &consumed) else { return nil }
			guard let value = String.decode(from: data, consumed: &consumed) else { return nil }
			versions[key] = value
		}

		return ServerConnectMessage(versions: versions)
	}
}

/// A TriggerVibration message
///
/// When received by SERVER, it sends this message to all clients
/// When received by CLIENT, it vibrates
public struct TriggerVibrationMessage: NetMessage
{
	/// The Payload Id for this message
	public static var payloadId: String { return "D22044F1-94D3-4331-8C98-39B1B93B3310" }

	public init()
	{
	}

	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> TriggerVibrationMessage?
	{
		return TriggerVibrationMessage()
	}
}
