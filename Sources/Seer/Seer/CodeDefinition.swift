//
//  CodeDefinition.swift
//  Seer
//
//  Created by Paul Nettle on 11/16/16.
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

// ---------------------------------------------------------------------------------------------------------------------------------
// Local constants
// ---------------------------------------------------------------------------------------------------------------------------------

/// Defines a full code for scanning. A code is represented as a set of MarkDefinition objects, which
/// define each mark printed on a deck.
///
/// Marks are defined by MarkDefinition.
public final class CodeDefinition
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The configuration file that contains our decks (CodeDefinitions defined as a set of `DeckFormat`s)
	public static let kDeckFormatsJsonFilename = "decks.json"

	/// Our code definitions
	public static var codeDefinitions = [CodeDefinition]()

	/// We scale our error values by this much globally (makes it easier for humans to parse)
	private let kErrorScale: Real = 100.0

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The list of mark definitions that define the code in full
	public private(set) var markDefinitions = [MarkDefinition]()

	/// The full width of the code, in millimeters
	public private(set) var widthMM: Real = 0

	/// The marks that represent the bits in the CodeDefinition
	public private(set) var bitMarks = [MarkDefinition]()

	/// The landmarks that appear at the start of the definition, prior to any bits
	public private(set) var startLandmarks = [MarkDefinition]()

	/// The landmarks that have bits on both sides
	public private(set) var interiorLandmarks = [MarkDefinition]()

	/// The landmarks that appear at the end of the definition, after the last bit
	public private(set) var endLandmarks = [MarkDefinition]()

	/// Returns the total number of landmarks
	private var totalLandmarkCount: Int { return startLandmarks.count + interiorLandmarks.count + endLandmarks.count }

	/// The landmarks that neighbor a bit mark
	public private(set) var bitNeighboringLandmarks = [MarkDefinition]()

	/// Defines a handler for converting between card index/codes
	public let format: DeckFormat

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initialize a CodeDefinition, assigning it a name and a conversion object
	public init(format: DeckFormat)
	{
		self.format = format

		format.populateCodeDefinition(self)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// CodeDefinition array management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initializes a set of `DeckFormatConfig` objects from a configuration file
	///
	/// Call with `configBaseName` being just the base name of the config file. Generally, this will be the name of the config file
	/// based on the project using it. For example, the 'whisper' project might provide a `configBaseName` of `whisper.conf`.
	///
	/// This file will be searched for (in this order):
	///
	///     1. The main bundle's resources
	///     2. /etc
	///     3. /usr/local/etc
	///     4. User's homr directory
	public static func loadCodeDefinitions(configBaseName: String = CodeDefinition.kDeckFormatsJsonFilename, fastLoad: Bool = false, skipIgnored: Bool = true)
	{
		var success = false

		let filename = configBaseName
		var configFilePaths = [PathString]()

		configFilePaths.append(PathString("~/") + ".\(filename)")
		configFilePaths.append(PathString("/usr/local/etc") + filename)
		configFilePaths.append(PathString("/etc") + filename)

		if Bundle.main.resourcePath != nil
		{
			configFilePaths.append(PathString(Bundle.main.resourcePath!) + filename)
		}

		// Load our config files, in the order they appear on our paths
		var jsonFormats = [DeckFormat]()
		for path in configFilePaths
		{
			if let newFormats = apply(fromFile: path.toAbsolutePath(), existingFormats: jsonFormats, fastLoad: fastLoad, skipIgnored: skipIgnored)
			{
				jsonFormats.append(contentsOf: newFormats)
				success = true
			}
		}

		// Populate our `codeDefinitions` array
		for format in jsonFormats
		{
			// First, we initialize a code definition with the given format
			let codeDefinition = CodeDefinition(format: format)

			// Add it to our final list of code definitions
			CodeDefinition.codeDefinitions.append(codeDefinition)
		}

		if !success
		{
			gLogger.warn("Unable to load any deck format configuration files")
		}
	}

	/// Apply any configuration values found in the file `filePath`
	///
	/// `filePath` must point to a file containing a single JSON object with fields that coordinate with configuration values
	/// stored in this class.
	///
	/// If the file is loaded and parsed successfully, a `ConfigDict` representation of that file is returned, otherwise `nil` is
	/// returned. Note that this doesn't mean that any part of the `Config` object was updated as the resulting `ConfigDict` may
	/// be empty or may contain values that do not map to values stored in this `Config` object.
	private static func apply(fromFile filePath: PathString, existingFormats: [DeckFormat], fastLoad: Bool = false, skipIgnored: Bool = true) -> [DeckFormat]?
	{
		var jsonFormats = [DeckFormat]()
		do
		{
			// Is the file actually a directory?
			if filePath.isDirectory()
			{
				throw "Deck format config file specifies directory: \(filePath)"
			}

			// Ensure it's a file that exists
			if !filePath.isFile()
			{
				return nil
			}

			gLogger.info("Loading deck format config file from \(filePath)")

			// Try to load the file
			guard let configData = try? Data(contentsOf: filePath.toUrl(), options: .uncached) else
			{
				throw "Unable to load deck format config file: \(filePath)"
			}

			// Try to deserialize it
			do
			{
				guard let json = try JSONSerialization.jsonObject(with: configData, options: []) as? [String: Any] else
				{
					throw "Serialization could not convert to [String: Any]"
				}

				guard let formats = json["formats"] as? [[String: Any]] else
				{
					throw "Failed to get 'formats' from deck format config JSON"
				}

				/// Our mutex used to prevent logger re-entry
				let formatMutex = PThreadMutex()
				let threadsRunning = Atomic<Int>(0)

				for format in formats
				{
					// If this format already exists, skip it
					guard let name = format["name"] as? String else { continue }

					var matchFound = false
					formatMutex.fastsync
					{
						for matchFormat in jsonFormats
						{
							if matchFormat.name == name
							{
								matchFound = true
								break
							}
						}
					}

					if matchFound { continue }

					for matchFormat in existingFormats
					{
						if matchFormat.name == name
						{
							matchFound = true
							break
						}
					}

					if matchFound { continue }

					// We'll check the ignore flag here so we don't suffer the overhead of starting a thread for ignored formats
					if skipIgnored && format["ignored"] as? Bool ?? false { continue }

					// Load the format in a thread
					let thread = Thread.init
					{
						if let newFormat = DeckFormat(json: format, fastLoad: fastLoad)
						{
							formatMutex.fastsync
							{
								jsonFormats.append(newFormat)
							}
						}

						threadsRunning.mutate { $0 -= 1 }
					}

					threadsRunning.mutate { $0 += 1 }
					thread.start()
				}

				let sleepInterval: TimeInterval = TimeInterval(10) / TimeInterval(1000)
				while threadsRunning.value > 0
				{
					Thread.sleep(forTimeInterval: sleepInterval)
				}

				return jsonFormats
			}
			catch
			{
				throw "Unable to deserialize deck format config file: \(filePath): \(error.localizedDescription)"
			}
		}
		catch
		{
			// We don't log errors since these errors may be normal - also, we haven't fully configured the logging.
			gLogger.error(error.localizedDescription)
		}

		return nil
	}

	/// Returns the code definition matching the given `name` or `nil` if not found
	public class func findCodeDefinition(byName name: String) -> CodeDefinition?
	{
		let searchName = name.lowercased()
		for codeDefinition in codeDefinitions
		{
			if codeDefinition.format.name.lowercased() == searchName || name == codeDefinition.format.name.lowercased()
			{
				return codeDefinition
			}
		}

		return nil
	}

	/// Returns the code definition matching the given `name` or `nil` if not found
	public class func findCodeDefinition(byId id: Int) -> CodeDefinition?
	{
		for codeDefinition in codeDefinitions
		{
			if Int(codeDefinition.format.id) == id
			{
				return codeDefinition
			}
		}

		return nil
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Implementation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the code definition after the `self` in the list of `codeDefinitions`
	///
	/// If `self` is the last in the arrry, the first `CodeDefinition` will be returned.
	///
	/// If `self` is not in the list of `codeDefinitions` then the first entry will be returned and cycling through the list will
	/// never return to this instance.
	public func nextCodeDefinition() -> CodeDefinition
	{
		// We need at least one to provide a new code definition to switch to
		//
		// This *should* never happen, but it is possible that the list of `codeDefinitions` is empty and `self` was an instance
		// manually created that is not part of the list.
		if CodeDefinition.codeDefinitions.count < 1 { return self }

		// Find our current code definition
		var currentIndex = 0

		for i in 0..<CodeDefinition.codeDefinitions.count
		{
			if self == CodeDefinition.codeDefinitions[i]
			{
				currentIndex = i
				break
			}
		}

		// Pick the next one
		currentIndex = (currentIndex + 1) % CodeDefinition.codeDefinitions.count

		return CodeDefinition.codeDefinitions[currentIndex]
	}

	/// Adds a MarkDefinition to this CodeDefinition. All MarkDefinitions must be added in sequential order from
	/// left to right and they must define the full deck, including any gaps (use MarkType.Space for gaps)
	///
	/// Before using a CodeDefinition, the following conditions must be met:
	///
	///		(1) All MarkDefinitions must be added
	///		(2) The code definition must be finalized (see finalize())
	///
	/// Note that the first and last MarkDefinitions must be Landmarks.
	public func addMarkDefinition(type: MarkType, widthMM: Real)
	{
		// Create a MarkDefinition and add it to this CodeDefinition
		let markDefinition = MarkDefinition(type: type, index: markDefinitions.count, startMM: self.widthMM, widthMM: widthMM)
		markDefinitions.append(markDefinition)

		// Update our width to include the new MarkDefinition
		self.widthMM += widthMM
	}

	/// Finalizes the CodeDefinition by building the supplementary data based on the current set of MarkDefinitions currently in
	/// the code definition.
	public func finalize()
	{
		// Reset our data
		bitMarks.removeAll()
		startLandmarks.removeAll()
		endLandmarks.removeAll()
		interiorLandmarks.removeAll()
		bitNeighboringLandmarks.removeAll()

		// Build our list of bitMarks
		var lastBitIndex = 0
		for md in markDefinitions
		{
			if let thisBitIndex = md.type.bitIndex
			{
				// If you hit this assert, then you've created a code definition in which the bits do not start at zero and
				// continue sequentially.
				assert(thisBitIndex == lastBitIndex)
				bitMarks.append(md)
				lastBitIndex += 1
			}
		}

		/// Normalize all marks to the current width
		for i in 0..<markDefinitions.count
		{
			markDefinitions[i].normalize(to: self.widthMM)
		}

		if bitMarks.count != 0
		{
			// These will help with our start/interior/end landmark arrays
			if let firstBitmarkIndex = bitMarks.first?.index
			{
				if let lastBitmarkIndex = bitMarks.last?.index
				{
					// Build our landmark lists
					for md in markDefinitions
					{
						// We're only interested in landmarks
						if md.type != .Landmark { continue }

						// Accumulate start/interior/end landmarks
						if md.index < firstBitmarkIndex
						{
							startLandmarks.append(md)
						}
						else if md.index > lastBitmarkIndex
						{
							endLandmarks.append(md)
						}
						else
						{
							interiorLandmarks.append(md)
						}

						// Accumulate bit-neighboring landmarks
						//
						// We do this by scanning forward and backwards from the current mark definition to find the next (or previous)
						// mark definition that is not a space. If it is a bit, then this is considered a bit-neighboring landmark
						var isNeighbor = false

						// Search backwards
						if md.index > 0
						{
							for i in stride(from: md.index-1, through: 0, by: -1)
							{
								if markDefinitions[i].type.isSpace { continue }
								if markDefinitions[i].type.isLandmark { break }
								if markDefinitions[i].type.isBit { isNeighbor = true; break }
							}
						}

						// search forwards
						if !isNeighbor && md.index < markDefinitions.count - 1
						{
							for i in md.index+1..<markDefinitions.count - 1
							{
								if markDefinitions[i].type.isLandmark { break }
								if markDefinitions[i].type.isBit { isNeighbor = true; break }
							}
						}

						if isNeighbor
						{
							bitNeighboringLandmarks.append(md)
						}
					}
				}
			}
		}

		// See `MarkDefinition.landmarkMinGapRatio` for details on this calculation
		for i in 1..<markDefinitions.count - 1
		{
			let thisMark = markDefinitions[i]
			if !thisMark.type.isLandmark { continue }
			let prevMark = markDefinitions[i-1]
			if !prevMark.type.isSpace { continue }
			let nextMark = markDefinitions[i+1]
			if !nextMark.type.isSpace { continue }

			let minGapMM = min(prevMark.widthMM, nextMark.widthMM) / 2
			markDefinitions[i].landmarkMinGapRatio = FixedPoint(minGapMM / thisMark.widthMM)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Deck measurements & limits
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the minimum width (in samples) that a code printed on a deck must occupy in the image in order to allow for
	/// enough vertical samples to support decoding.
	///
	/// Note that this does not guarantee decoding will be possible, as a deck may be viewed at angles that reduce the vertical
	/// height in image space.
	///
	/// We optionally include the deck's angle normal. If provided, our height is adjusted based on the angle of the deck in order
	/// to meet the minimum requirement returned, in pixels. The `withDeckAngleNormal` parameter represents any Vector of unit
	/// length that points along either the deck's vertical or horizontal axis.
	public func calcMinSampleWidth(withDeckAngleNormal normal: Vector? = nil) -> Real
	{
		return calcMinSampleHeight(withDeckAngleNormal: normal, forCardCount: format.maxCardCount) * widthMM / format.physicalStackHeightMM
	}

	/// Returns the minimum height (in samples) that a code printed on a deck must occupy in the image in order to allow for
	/// enough vertical samples to support decoding.
	///
	/// We optionally include the deck's angle normal. If provided, our height is adjusted based on the angle of the deck in order
	/// to meet the minimum requirement returned, in pixels. The `withDeckAngleNormal` parameter represents any Vector of unit
	/// length that points along either the deck's vertical or horizontal axis.
	public func calcMinSampleHeight(withDeckAngleNormal normal: Vector? = nil, forCardCount cardCount: Int) -> Real
	{
		var adjustment: Real = 1
		if let normal = normal
		{
			// We adjust our count based on the angle to account for diagonal pixels
			//
			// Here, we calculate a scalar value which ranges from [0, 1] for dot product [0, 0.5]

			// A unit vector to use as a basis for what is orthogonal. Note that either (0, 1) or (1, 0) would work
			let orthoNormal = Vector(x: 0, y: 1)

			// Dot the input normal with our ortho normal. Note that whole numbers represent ortho angles while fractions
			// approaching -0.5 and +0.5 represent increasing amount of diagonal angle. Therefore:
			//
			// (-1.0  -> -0.5 ->  0.0  -> +0.5 ->  +1.0)
			// =========================================
			// (ortho -> diag -> ortho -> diag -> ortho)
			let a = normal ^ orthoNormal

			// Simplify:
			//
			// (0.0   -> +0.5 ->  +1.0)
			// ========================
			// (ortho -> diag -> ortho)
			let b = abs(a)

			// Transform to a diagonal half-scalar:
			//
			// (0.0  ->  +0.5)
			// ===============
			// (diag -> ortho)
			let c = abs(b - 0.5)

			// Scale our half-scalar to a unit scalar:
			//
			// (0.0  ->  +1.0)
			// ===============
			// (diag -> ortho)
			let d = c * 2

			// We want our diagonals to be the full scalar, with orthos receiving no ajustment, so invert:
			//
			// (0.0   -> +1.0)
			// ===============
			// (ortho -> diag)
			let adjustmentScalar = 1 - d

			// Finally, we calculate the full adjustment, which is a difference between 1.0 (no adjustment) and a perfect diagonal,
			// sqrt(1^1 + 1^1).
			let sqrt2: Real = 1.4142135624
			let delta = 1 - sqrt2
			adjustment += delta * adjustmentScalar
		}

		return format.getMinSampleHeight(forCardCount: cardCount) * adjustment
	}

	public func narrowestLandmarkNormalizedWidth() -> Real
	{
		var narrowestWidth: Real = 1.0
		for landmark in startLandmarks
		{
			if landmark.normalizedWidth < narrowestWidth { narrowestWidth = landmark.normalizedWidth }
		}
		for landmark in interiorLandmarks
		{
			if landmark.normalizedWidth < narrowestWidth { narrowestWidth = landmark.normalizedWidth }
		}
		for landmark in endLandmarks
		{
			if landmark.normalizedWidth < narrowestWidth { narrowestWidth = landmark.normalizedWidth }
		}

		return narrowestWidth
	}

	/// Returns the height (in samples) that a code printed on a deck occupies in the image, based on the given width.
	///
	/// Note that this is not guaranteed to be accurate as it does not take into consideration any angle from scanning.
	public func calcSampleHeightFromScanWidth(width: Real) -> Real
	{
		return Real(width) / widthMM * format.physicalStackHeightMM
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Matching
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns a DeckMatchResult representing the best match (least error) for our CodeDefinition from the given set of
	/// MarkLocations
	///
	/// We do this by reducing the set of MarkLocations into single points (their center) and seeing if those points fall within
	/// the bounds of a MarkDefinition. If we get a full set of MarkDefinitions, then they are built into a DeckLocation and the
	/// error is calculated. If we get multiple possible DeckLocations, the one with the least error is returned.
	public func bestMatch(markLocations inMarkLocations: [MarkLocation]) -> DeckMatchResult?
	{
		// The definition must always start and stop with a landmark MarkDefinition so it can be located
		assert(!startLandmarks.isEmpty && !endLandmarks.isEmpty)

		// For convenience
		let startLandmarkCount = startLandmarks.count
		let interiorLandmarkCount = interiorLandmarks.count
		let endLandmarkCount = endLandmarks.count
		let totalLandmarkCount = startLandmarkCount + interiorLandmarkCount + endLandmarkCount

		// Ensure we have enough marks
		if inMarkLocations.count < totalLandmarkCount { return nil }

		// We could end up with multiple candidate DeckLocations so we'll keep track of the best
		var bestResult: DeckMatchResult?

		// Prepare an array to store our candidate mark locations for the match
		var candidateMarkLocations = [MarkLocation]()
		candidateMarkLocations.reserveCapacity(totalLandmarkCount)

		// Start Landmark group range
		for startGroupFirstIndex in 0...inMarkLocations.count - totalLandmarkCount
		{
			// End Landmark group range
			for endGroupFirstIndex in startGroupFirstIndex + startLandmarkCount + interiorLandmarkCount...inMarkLocations.count - endLandmarkCount
			{
				// Create a DeckLocation from our markLocations
				let workingDeck = DeckLocation(markLocations: Array(inMarkLocations[startGroupFirstIndex...endGroupFirstIndex + endLandmarkCount - 1]))
				var markLocations = workingDeck.markLocations

				// The range of interior marks
				let firstInteriorMarkIndex = startLandmarkCount
				let lastInteriorMarkIndex = markLocations.count - endLandmarkCount - 1

				// Populate our list of candidate mark locations with the initial set of our consecutive start marks. As we do
				// this, we'll store the matchDefinitionIndex for each MarkLocation so later we can match them up with the
				// MarkDefinitions that they were matched with.
				candidateMarkLocations.removeAll(keepingCapacity: true)
				for i in 0..<startLandmarkCount
				{
					markLocations[i].matchedDefinitionIndex = startLandmarks[i].index
					candidateMarkLocations.append(markLocations[i])
				}

				// Find candidates for our interior landmarks
				for interiorLandmarkDefinition in interiorLandmarks
				{
					let markDefinitionCenter = interiorLandmarkDefinition.normalizedCenter
					var bestMarkLocation: MarkLocation?
					var bestDistance: Real = 0

					for interiorMarkIndex in firstInteriorMarkIndex...lastInteriorMarkIndex
					{
						var markLocation = markLocations[interiorMarkIndex]
						let markLocationCenter = (markLocation.start.normalizedLocation + markLocation.end.normalizedLocation) / 2
						let distance = abs(markDefinitionCenter - markLocationCenter)
						if bestMarkLocation == nil || distance < bestDistance
						{
							// We also set the matchedDefinitionIndex for this MarkLocation so we know where it belongs
							markLocation.matchedDefinitionIndex = interiorLandmarkDefinition.index

							bestMarkLocation = markLocation
							bestDistance = distance
						}
					}

					// Sanity check
					assert(bestMarkLocation != nil)

					if let bestMarkLocation = bestMarkLocation
					{
						// If our best is already in the list, then our best isn't our best, so let's skip this grouping altogether
						var skipFlag = false
						for candidateMark in candidateMarkLocations
						{
							if candidateMark.scanIndex == bestMarkLocation.scanIndex
							{
								skipFlag = true
								break
							}
						}

						// Should we skip this one?
						if skipFlag
						{
							candidateMarkLocations.removeAll(keepingCapacity: true)
							break
						}

						// Add the candidate
						candidateMarkLocations.append(bestMarkLocation)
					}
				}

				// Did we decide we needed to skip this group?
				if candidateMarkLocations.count == 0 { continue }

				// Add the final set of consecutive end marks, keeping track of the markDefinitionIndex along the way
				for i in markLocations.count - endLandmarkCount..<markLocations.count
				{
					markLocations[i].matchedDefinitionIndex = endLandmarks[i - (markLocations.count - endLandmarkCount)].index
					candidateMarkLocations.append(markLocations[i])
				}

				// Our candidate deck
				let candidateDeck = DeckLocation(markLocations: candidateMarkLocations)

				// Build a DeckLocation and calculate error
				if let error = calcRMSD(deckLocation: candidateDeck)
				{
					// If this is a better candidate, store it
					if bestResult == nil || error < bestResult!.error
					{
						bestResult = DeckMatchResult(deckLocation: candidateDeck, error: error)
					}
				}
			}
		}

		return bestResult
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns an array of unit scalars representing normalized centers of bit marks between the centers of the given LandMarks
	///
	/// IMPORTANT: It is worth reiterating that the normalized centers of the bit marks are relative to the centers of the two
	/// input landmarks. Not taking this into consideration will offset them to the right by half of the left landmark's width.
	public func normalizeBitMarks(from leftLandmarkDef: MarkDefinition, to rightLandmarkDef: MarkDefinition) -> [Real]?
	{
		assert(markDefinitions.count > 0)
		assert(leftLandmarkDef.type.isLandmark && rightLandmarkDef.type.isLandmark)

		// The definition space range of the landmarks that encompass all bits
		//
		// Note that the start and end are centered on their marks
		let defSpaceStart = (leftLandmarkDef.startMM + leftLandmarkDef.endMM) / 2
		let defSpaceEnd = (rightLandmarkDef.startMM + rightLandmarkDef.endMM) / 2
		let defSpaceRange = defSpaceEnd - defSpaceStart

		// This is our output
		var normalizedCenters = [Real]()
		normalizedCenters.reserveCapacity(markDefinitions.count)

		// Our definition-space sub-range starting position. Note that we start at the end of the left-most landmark definition
		let subDefSpaceStart = leftLandmarkDef.endMM - defSpaceStart

		// Calculate our initial (normalized) offset
		var offset: Real = subDefSpaceStart / defSpaceRange

		// Visit each of the mark definitions between the pair landmarks
		for i in leftLandmarkDef.index+1..<rightLandmarkDef.index
		{
			// Normalize the width of our mark definition to the requested definition-space range so we get a unit scalar covering
			// that range exactly
			let markDefinition = markDefinitions[i]
			let markNormalizedWidth = markDefinition.widthMM / defSpaceRange

			// We only report on bit marks (and then, only their normalized centers)
			if markDefinition.type.isBit
			{
				normalizedCenters.append(offset + markNormalizedWidth / 2)
			}

			// Update our offset to the next mark
			offset += markNormalizedWidth
		}

		return normalizedCenters
	}

	/// Calculates the error for a deck using Root Mean Standard Error method
	private func calcRMSD(deckLocation: DeckLocation) -> Real?
	{
		if deckLocation.markCount != totalLandmarkCount
		{
			return nil
		}

		// Calculate the squared deviations for each edge of our landmarks
		var squaredDeviations: Real = 0.0
		var markIndex = 0
		var deviationCount = 0
		for markDefinition in markDefinitions
		{
			// Skip non-landmarks
			if !markDefinition.type.isLandmark { continue }

			// Our current mark
			let markLocation = deckLocation.markLocations[markIndex]
			markIndex += 1

			// Error for the markLocation start/end positions
			let startErr = markLocation.start.normalizedLocation - markDefinition.normalizedStart
			squaredDeviations += startErr * startErr
			deviationCount += 1

			let endErr = markLocation.end.normalizedLocation - markDefinition.normalizedEnd
			squaredDeviations += endErr * endErr
			deviationCount += 1

//			let markNormalizedWidth = markLocation.end.normalizedLocation - markLocation.start.normalizedLocation
//			let widthErr = markNormalizedWidth - markDefinition.normalizedWidth
//			squaredDeviations += widthErr * widthErr
//			deviationCount += 1
		}

		let variance = squaredDeviations / Real(deviationCount)
		let error = Real(sqrt(Double(variance))) * kErrorScale

		// Limit our error
		if error >= Config.searchMaxDeckMatchError
		{
			return nil
		}

		return error
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Debug
	// -----------------------------------------------------------------------------------------------------------------------------

	public func debugDrawOverlay(image: DebugBuffer?, deckReference deckLocation: DeckLocation)
	{
		// Draw our mark definitions
		for markDefinition in markDefinitions
		{
			markDefinition.debugDrawOverlay(image: image, deckReference: deckLocation)
		}
	}
}

/// Conformance for Equatable
extension CodeDefinition: Equatable
{
	public static func == (lhs: CodeDefinition, rhs: CodeDefinition) -> Bool
	{
		return lhs.format.name == rhs.format.name
	}

	public static func != (lhs: CodeDefinition, rhs: CodeDefinition) -> Bool
	{
		return !(lhs == rhs)
	}
}

extension CodeDefinition: Codable
{
	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !format.name.encode(into: &data) { return false }
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> CodeDefinition?
	{
		guard let formatName = String.decode(from: data, consumed: &consumed) else { return nil }
		return CodeDefinition.findCodeDefinition(byName: formatName)
	}
}
