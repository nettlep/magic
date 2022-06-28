//
//  ServerConfig.swift
//  magic
//
//  Created by Paul Nettle on 10/21/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI
#if os(iOS)
import SeerIOS
import MinionIOS
#else
import Seer
import Minion
#endif

class ServerConfig: ObservableObject
{
	public class Value: ObservableObject, Equatable
	{
		private var shouldSend = true

		// We publish a string value for use with text input fields for inputting numeric values
		@Published public var uiStringValue: String = ""

		public var category: String
		public var name: String
		public var type: Config.ValueType
		public var description: String

		public var stringValue: String = ""
		{
			didSet
			{
				sendUpdate()
				uiStringValue = stringValue
			}
		}
		public var stringMapValue: [String: String] = [:]
		{
			didSet
			{
				sendUpdate()
			}
		}
		public var pathValue: PathString = PathString()
		{
			didSet
			{
				sendUpdate()
				uiStringValue = pathValue.toString()
			}
		}
		public var pathArrayValue: [PathString] = [PathString]()
		{
			didSet
			{
				sendUpdate()
			}
		}
		public var codeDefinitionValue: CodeDefinition?
		{
			didSet
			{
				sendUpdate()

				let definition = codeDefinitionValue
				DispatchQueue.main.async
				{
					UIState.shared.deckFormatName = definition?.format.name
				}

				Preferences.shared.deckFormatName = codeDefinitionValue?.format.name

				if Config.searchCodeDefinition?.format.name != definition?.format.name
				{
					Config.searchCodeDefinition = definition
				}
			}
		}
		public var booleanValue: Bool = false
		{
			didSet
			{
				sendUpdate()
				uiStringValue = String(booleanValue)
			}
		}
		public var integerValue: Int = 0
		{
			didSet
			{
				sendUpdate()
				uiStringValue = String(integerValue)

				// Special handling for viewport type updates
				if fullName == "capture.ViewportType"
				{
					let viewportType = ViewportMessage.ViewportType.fromUInt8(UInt8(integerValue))
					DispatchQueue.main.async
					{
						UIState.shared.viewportType = viewportType
					}

					if Config.captureViewportType != viewportType
					{
						Config.captureViewportType = viewportType
					}
				}
			}
		}
		public var fixedPointValue: FixedPoint = 0
		{
			didSet
			{
				sendUpdate()
				uiStringValue = String(format: "%.3f", fixedPointValue.toFloat())
			}
		}
		public var realValue: Real = 0
		{
			didSet
			{
				sendUpdate()
				uiStringValue = String(format: "%.3f", realValue)
			}
		}
		public var rollValueValue: RollValue = 0
		{
			didSet
			{
				sendUpdate()
				uiStringValue = String(format: "%.3f", rollValueValue)
			}
		}
		public var timeValue: Time = 0
		{
			didSet
			{
				sendUpdate()
				uiStringValue = String(format: "%.3f", timeValue)
			}
		}

		required init(category: String, name: String, type: Config.ValueType, description: String)
		{
			self.category = category
			self.name = name
			self.type = type
			self.description = description
		}

		convenience init(category: String, name: String, type: Config.ValueType, description: String, value: Any)
		{
			self.init(category: category, name: name, type: type, description: description)
			disableSend {
				set(value: value, initialValue: true)
			}
		}

		public static func == (lhs: ServerConfig.Value, rhs: ServerConfig.Value) -> Bool {
			return
				lhs.category == rhs.category &&
				lhs.name == rhs.name &&
				lhs.type == rhs.type &&
				lhs.description == rhs.description &&
				lhs.stringValue == rhs.stringValue &&
				lhs.stringMapValue == rhs.stringMapValue &&
				lhs.pathValue == rhs.pathValue &&
				lhs.pathArrayValue == rhs.pathArrayValue &&
				lhs.codeDefinitionValue == rhs.codeDefinitionValue &&
				lhs.booleanValue == rhs.booleanValue &&
				lhs.integerValue == rhs.integerValue &&
				lhs.fixedPointValue == rhs.fixedPointValue &&
				lhs.realValue == rhs.realValue &&
				lhs.rollValueValue == rhs.rollValueValue &&
				lhs.timeValue == rhs.timeValue
		}

		var fullName: String
		{
			return "\(category).\(name)"
		}

		/// Disables sending updates for the duration of the `action` block. This is used for scnearios where we want to update a value but do not want to broadcast that
		/// update to the server.
		func disableSend(_ action: () -> Void)
		{
			shouldSend = false
			action()
			shouldSend = true
		}

		/// Sets the value based on its type
		///
		/// This method is intended to be called for internal updates. That is, updates from within the local app that should be propagated to the server (and from there, out to
		/// other clients.)
		func set(value: Any, initialValue: Bool = false)
		{
			switch self.type
			{
			case .String:
				guard let value = value as? String else
				{
					gLogger.error("ServerConfig.Value.setValue: Failed to set String value for name '\(self.fullName)' - value was nil")
					return
				}
				if !initialValue && self.stringValue == value { return }
				self.stringValue = value
			case .Path:
				guard let value = value as? PathString else
				{
					gLogger.error("ServerConfig.Value.setValue: Failed to set Path value for name '\(self.fullName)' - value was nil")
					return
				}
				if !initialValue && self.pathValue == value { return }
				self.pathValue = value
			case .PathArray:
				guard let value = value as? [PathString] else
				{
					gLogger.error("ServerConfig.Value.setValue: Failed to set PathArray value for name '\(self.fullName)' - value was nil")
					return
				}
				if !initialValue && self.pathArrayValue == value { return }
				self.pathArrayValue = value
			case .CodeDefinition:
				guard let value = value as? CodeDefinition else
				{
					gLogger.error("ServerConfig.Value.setValue: Failed to set CodeDefinition value for name '\(self.fullName)' - value was nil")
					return
				}
				if !initialValue && self.codeDefinitionValue?.format.name == value.format.name { return }
				self.codeDefinitionValue = value
			case .StringMap:
				guard let value = value as? [String: String] else
				{
					gLogger.error("ServerConfig.Value.setValue: Failed to set StringMap value for name '\(self.fullName)' - value was nil")
					return
				}
				if !initialValue && self.stringMapValue == value { return }
				self.stringMapValue = value
			case .Boolean:
				guard let value = value as? Bool else
				{
					gLogger.error("ServerConfig.Value.setValue: Failed to set Boolean value for name '\(self.fullName)' - value was nil")
					return
				}
				if !initialValue && self.booleanValue == value { return }
				self.booleanValue = value
			case .Integer:
				guard let value = value as? Int else
				{
					gLogger.error("ServerConfig.Value.setValue: Failed to set Integer value for name '\(self.fullName)' - value was nil")
					return
				}
				if !initialValue && self.integerValue == value { return }
				self.integerValue = value
			case .FixedPoint:
				guard let value = value as? FixedPoint else
				{
					gLogger.error("ServerConfig.Value.setValue: Failed to set FixedPoint value for name '\(self.fullName)' - value was nil")
					return
				}
				if !initialValue && self.fixedPointValue == value { return }
				self.fixedPointValue = value
			case .Real:
				guard let value = value as? Real else
				{
					gLogger.error("ServerConfig.Value.setValue: Failed to set Real value for name '\(self.fullName)' - value was nil")
					return
				}
				if !initialValue && self.realValue == value { return }
				self.realValue = value
			case .RollValue:
				guard let value = value as? RollValue else
				{
					gLogger.error("ServerConfig.Value.setValue: Failed to set RollValue value for name '\(self.fullName)' - value was nil")
					return
				}
				if !initialValue && self.rollValueValue == value { return }
				self.rollValueValue = value
			case .Time:
				guard let value = value as? Time else
				{
					gLogger.error("ServerConfig.Value.setValue: Failed to set Time value for name '\(self.fullName)' - value was nil")
					return
				}
				if !initialValue && self.timeValue == value { return }
				self.timeValue = value
			}

			// Internal changes trigger a publish on the ServerConfig to allow the UI to recognize the updates
			ServerConfig.shared.publish()
		}

		/// Sets the value from the contents of a message received from the server
		///
		/// This method will disable updates (via `disableSend`). This is important because changes to values would normally trigger an automatic message to the server,
		/// which in turn would broadcast that message to all clients, bringing us right back here, where the loop would repeat.
		func set(message: ConfigValueMessage)
		{
			disableSend {
				switch message.valueType
				{
				case .String:
					set(value: message.stringValue!)
				case .Path:
					set(value: message.pathValue!)
				case .PathArray:
					set(value: message.pathArrayValue!)
				case .CodeDefinition:
					set(value: message.codeDefinitionValue!)
				case .StringMap:
					set(value: message.stringMapValue!)
				case .Boolean:
					set(value: message.booleanValue!)
				case .Integer:
					set(value: message.integerValue!)
				case .FixedPoint:
					set(value: message.fixedPointValue!)
				case .Real:
					set(value: message.realValue!)
				case .RollValue:
					set(value: message.rollValue!)
				case .Time:
					set(value: message.timeValue!)
				}
			}
		}

		func get() -> Any?
		{
			switch self.type
			{
			case .String:
				return stringValue
			case .Path:
				return pathValue
			case .PathArray:
				return pathArrayValue
			case .CodeDefinition:
				return codeDefinitionValue
			case .StringMap:
				return stringMapValue
			case .Boolean:
				return booleanValue
			case .Integer:
				return integerValue
			case .FixedPoint:
				return fixedPointValue
			case .Real:
				return realValue
			case .RollValue:
				return rollValueValue
			case .Time:
				return timeValue
			}
		}

		func sendUpdate()
		{
			if !shouldSend { return }

			gLogger.network("Sending update of value \(fullName) to server")

			var message: ConfigValueMessage?

			switch self.type
			{
			case .String:
				message = ConfigValueMessage(name: self.fullName, withString: self.stringValue)
			case .Path:
				message = ConfigValueMessage(name: self.fullName, withPath: self.pathValue)
			case .PathArray:
				message = ConfigValueMessage(name: self.fullName, withPathArray: self.pathArrayValue)
			case .CodeDefinition:
				if let codeDefinitionValue = self.codeDefinitionValue
				{
					message = ConfigValueMessage(name: self.fullName, withCodeDefinition: codeDefinitionValue)
				}
			case .StringMap:
				message = ConfigValueMessage(name: self.fullName, withStringMap: self.stringMapValue)
			case .Boolean:
				message = ConfigValueMessage(name: self.fullName, withBoolean: self.booleanValue)
			case .Integer:
				message = ConfigValueMessage(name: self.fullName, withInteger: self.integerValue)
			case .FixedPoint:
				message = ConfigValueMessage(name: self.fullName, withFixedPoint: self.fixedPointValue)
			case .Real:
				message = ConfigValueMessage(name: self.fullName, withReal: self.realValue)
			case .RollValue:
				message = ConfigValueMessage(name: self.fullName, withRollValue: self.rollValueValue)
			case .Time:
				message = ConfigValueMessage(name: self.fullName, withTime: self.timeValue)
			}

			if let payload = message?.getPayload()
			{
				DispatchQueue.global().async
				{
					if !(AbraApp.shared.clientPeer?.send(payload) ?? true)
					{
						gLogger.error("ServerConfig.Value.setValue: Failed to send config value: '\(self.fullName)'")
					}
				}
			}
			else
			{
				gLogger.error("ServerConfig.Value.setValue: Failed to build message for new config value: '\(self.fullName)'")
			}
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	@Published public var values = [Value]()
	private var valuesMutex = PThreadMutex()

	// -----------------------------------------------------------------------------------------------------------------------------
	// Provide a singleton-like interface
	// -----------------------------------------------------------------------------------------------------------------------------

	public static var shared = ServerConfig()

	// Private to prevent external instantiation
	private init() {}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Server config management, for publishing changes to server configs
	// -----------------------------------------------------------------------------------------------------------------------------

	/// We provide a custom publish method,
	///
	/// We need this since we're nesting our ObservableObjects in a dynamic array, which do not propagate changes up the hierarchy and we can't use @Binding to each element
	/// in the array.
	internal func publish()
	{
		DispatchQueue.main.async
		{
			self.objectWillChange.send()
		}
	}

	func populate(_ newValues: [ConfigValueListMessage.ConfigValue])
	{
		DispatchQueue.main.async {
			self.valuesMutex.fastsync
			{
				// Update existing values
				for newValue in newValues
				{
					if let index = self.values.firstIndex(where: { $0.fullName == newValue.fullName })
					{
						self.values[index].set(value: newValue.value)
					}
					else
					{
						self.values.append(Value(category: newValue.category, name: newValue.name, type: newValue.type, description: newValue.description, value: newValue.value))
					}
				}

				// Remove existing values not part of the new set
				self.values.removeAll(where: { existingValue in
					newValues.firstIndex(where: { $0.fullName == existingValue.fullName }) == nil
				})

				// Keep our values sorted
				self.values.sort(by: { $0.fullName < $1.fullName })
			}
		}
	}

	func set(message: ConfigValueMessage)
	{
		var found = false
		valuesMutex.fastsync
		{
			for i in 0..<values.count
			{
				if values[i].fullName == message.name
				{
					values[i].set(message: message)
					found = true
					break
				}
			}
		}

		if !found
		{
			gLogger.error("ServerConfig.set(message:): Unable to locate server config value: \(message.name)")
		}
	}

	func set(fullName: String, value: Any)
	{
		var found = false
		valuesMutex.fastsync
		{
			for i in 0..<values.count
			{
				if values[i].fullName == fullName
				{
					values[i].set(value: value)
					found = true
					break
				}
			}
		}

		if !found
		{
			gLogger.error("ServerConfig.set(name:value:): Unable to locate server config value: \(fullName)")
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// UI publishing of specific values that are exposed beyond the ServerConfigView
	// -----------------------------------------------------------------------------------------------------------------------------

	func setCodeDefinition(withName name: String?)
	{
		var codeDefinition: CodeDefinition?
		if let name = name
		{
			codeDefinition = CodeDefinition.findCodeDefinition(byName: name)
		}

		if Config.searchCodeDefinition?.format.name != codeDefinition?.format.name
		{
			Config.searchCodeDefinition = codeDefinition
		}

		valuesMutex.fastsync
		{
			for i in 0..<values.count
			{
				if values[i].fullName == "search.CodeDefinition"
				{
					values[i].codeDefinitionValue = codeDefinition
					return
				}
			}
		}
	}

	func setViewportType(viewportType: ViewportMessage.ViewportType)
	{
		if Config.captureViewportType != viewportType
		{
			Config.captureViewportType = viewportType
		}

		valuesMutex.fastsync
		{
			for i in 0..<values.count
			{
				if values[i].fullName == "capture.ViewportType"
				{
					values[i].integerValue = Int(viewportType.rawValue)
					return
				}
			}
		}
	}
}
