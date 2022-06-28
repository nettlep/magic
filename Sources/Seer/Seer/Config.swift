//
//  Config.swift
//  Seer
//
//  Created by Paul Nettle on 3/22/17.
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
// Global access
// ---------------------------------------------------------------------------------------------------------------------------------

/// A application-level structure containing configuration data with granular control over contents of values via tiered loading of
/// configuration files.
///
/// The Config structure declares all configuration values for the application, storing them as properties such that they can be
/// accessed directly at runtime for optimal performance.
///
/// IMPORTANT NOTE ABOUT CASE SENSITIVITY
///
///		It is important to be aware the Swift's default behavior for key lookups in Dictionary collections (which is what a Config
///		object consists of) is fully case sensitive.
///
/// TIERED CONFIGURATION CONTROL
///
///		The values, as defined in the Config structure, define the default values for all configuration settings. It is not
///		necessary to load any configuration file(s) and the user can directly manipulate the settings as they see fit. However,
///		there also exists a simple yet powerful mechanism for loading a series of configuration files that can be leveraged to
///		apply granular control configuration values.
///
///		The tiered loading process always searches for a config file and applies each in order, with any data from one overwriting
///		the previous. See `loadConfiguration` for information on this tiered loading process.
///
/// WRITING THE CONGIGURATION FILE
///
///		The last file in the tiered chain that was loaded successfully is stored. If the file is config file is ever written, then
///		the file is stored to that location so that it has precedence over the others. If the most recent file loaded was from the
///		bundle, then the first non-bundle location is used. See the `write` method for more information.
///
/// CONFIG FILE FORMAT
///
///		A configuration files consists of a single JSON object. This object may be empty, or it may contain as many configuration
///		fields as desired. Any values in the configuration file that do not match up with a configuration value will be ignored.
public struct Config
{
	public enum ValueType: String
	{
		public typealias RawValue = String

		/// A string: stored in stringValue
		case String

		/// A string map, stored in stringMapValue
		case StringMap

		/// A path, stored in pathValue
		case Path

		/// An array of Paths, stored in pathArrayValue
		case PathArray

		/// A code definition, stored in codeDefinitionValue
		case CodeDefinition

		/// A boolean, stored in booleanValue
		case Boolean

		/// An integer, stored in integerValue
		case Integer

		/// A fixed point value, stored in fixedPointValue
		case FixedPoint

		/// A floating point value, stored in realValue
		case Real

		/// A rolling value, stored in rollValue
		case RollValue

		/// A rolling value, stored in timeValue
		case Time
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Local types
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The type used to store configuration data loaded from disk
	public typealias ConfigDict = [String: Any]

	/// Lambda type used to receive notifications that a value has changed
	///
	/// The `name` parameter receives the name of the property. If `name` is `nil`, then the entire configuration was loaded.
	public typealias ValueChangedNoticationReceiver = (_ name: String?) -> Void

	/// Internal struct for holding `ValueChangedNoticationReceiver`s with IDs so they can be removed
	private struct ValueChangedNotication
	{
		/// Static incremental identifier
		static var lastId = 0
		var receiver: ValueChangedNoticationReceiver
		var id: Int

		init(receiver: @escaping ValueChangedNoticationReceiver)
		{
			self.receiver = receiver
			ValueChangedNotication.lastId += 1
			self.id = ValueChangedNotication.lastId
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Constants
	// -----------------------------------------------------------------------------------------------------------------------------

	private static let kTempExtension = ".bak"

	// -----------------------------------------------------------------------------------------------------------------------------
	// Locals
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The configuration filename
	private static var configFilename: String?

	/// The list of value change notification receivers
	private static var valueChangedNotifications = [ValueChangedNotication]()

	// -----------------------------------------------------------------------------------------------------------------------------
	// Global variables from an external UI (used for debugging only)
	// -----------------------------------------------------------------------------------------------------------------------------

	/// We store the starting temporal state for each frame so that if we repeat a frame, we can repeat it with the same temporal
	/// state that was originally used on the frame
	public static var replayTemporalState = DeckSearch.TemporalState()

	/// Used to denote when a frame is being replayed, so that it can be replayed exactly the same as before (by using
	/// `replayTemporalState`)
	public static var isReplayingFrame: Bool = false

	/// The current mouse position from the UI
	public static var mousePosition = Vector()

	/// This will be true after a scan process if the scanner has requested a pause
	public static var pauseRequested: Bool = false

	/// A general purpose debug parameter that can be incremented and decremented during runtime
	public static var debugGeneralPurposeParameter = 0

	/// A general purpose debug parameter that can be incremented and decremented during runtime (via CTL)
	public static var debugGeneralPurposeParameterCtl = 0

	/// A general purpose debug parameter that can be incremented and decremented during runtime (via CMD)
	public static var debugGeneralPurposeParameterCmd = 0

	/// Determines which edge (in the sequential order of edges detected) to show detail for
	///
	/// Note that this only applies to edges that are marked as debuggable
	public static var debugEdgeDetectionSequenceId = 0

	// -----------------------------------------------------------------------------------------------------------------------------
	//  ____                     ____             __ _                       _   _
	// | __ )  __ _ ___  ___    / ___|___  _ __  / _(_) __ _ _   _ _ __ __ _| |_(_) ___  _ __
	// |  _ \ / _` / __|/ _ \  | |   / _ \| '_ \| |_| |/ _` | | | | '__/ _` | __| |/ _ \| '_ \
	// | |_) | (_| \__ \  __/  | |__| (_) | | | |  _| | (_| | |_| | | | (_| | |_| | (_) | | | |
	// |____/ \__,_|___/\___|   \____\___/|_| |_|_| |_|\__, |\__,_|_|  \__,_|\__|_|\___/|_| |_|
	//                                                 |___/
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	public private(set) static var configDict: [String: ConfigDict] =
	[
		// "Array of possible locations for the log file. The first value that can be written to will be used. If no value can be
		// written, then no log file will be generated. Absolute and relative paths are allowed. If the path begins with a tilde
		// ('~') then the path will be relative to the user's home directory.
		"log.FileLocations":
		[
			"value": ["/var/log/whisper.log", "/tmp/whisper.log", "whisper.log", "~/whisper.log"],
			"public": false,
			"type": ValueType.PathArray.rawValue,
			"description": "Array of possible locations for the log file. The first value that can be written to will be used. If no value can be written, then no log file will be generated. Absolute and relative paths are allowed. If the path begins with a tilde ('~') then the path will be relative to the user's home directory."
		],

		// Should the log be emptied on startup?
		"log.ResetOnStart":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Should the log be emptied on startup?"
		],
		"log.Masks":
		[
			"value": [
				"Console": "!all !debug  info  warn  error  severe  fatal !trace !perf !status !frame !search !decode !resolve !badresolve !correct !incorrect !result !badreport !network",
				"UI": "!all !debug  info  warn  error  severe  fatal !trace !perf !status !frame !search !decode !resolve !badresolve !correct !incorrect !result !badreport !network",
				"File": "!all !debug  info  warn  error  severe  fatal !trace !perf !status !frame !search !decode !resolve !badresolve !correct !incorrect !result !badreport !network"
			],
			"public": false,
			"type": ValueType.StringMap.rawValue,
			"description": "Log file masks (see `Logger` for details)"
		],

		// When writing diagnostic LUMA files, where to store them
		"diagnostic.LumaFilePath":
		[
			"value": "",
			"public": false,
			"type": ValueType.String.rawValue,
			"description": "When writing diagnostic LUMA files, where to store them"
		],

		// The application will reserve this much space on the system, failing to write data to the disk if it
		// causes the system to have this less than this much space
		"system.ReservedDiskSpaceMB":
		[
			"value": Int(500),
			"public": false,
			"type": ValueType.Integer.rawValue,
			"description": "The application will reserve this much space on the system, failing to write data to the disk if it causes the system to have this less than this much space"
		],

		// Minimum amount of variance in the data needed for reliable edge detection
		//
		// If the threshold is calculated to be less than this value, then there isn't enough variance in the source data
		// (specifically, the slopes) for reliable edge detection. In this case, the threshold is clamped to this value,
		// likely resulting in few or no edges detected.
		"edge.MinimumThreshold":
		[
			"value": Int(10),
			"public": true,
			"type": ValueType.RollValue.rawValue,
			"description": "Minimum amount of variance in the data needed for reliable edge detection\n\nIf the threshold is calculated to be less than this value, then there isn't enough variance in the source data (specifically, the slopes) for reliable edge detection. In this case, the threshold is clamped to this value, likely resulting in few or no edges detected."
		],

		// Specifies the priority of scanning horizontal (offset) versus rotated (angle) search lines
		//
		// Larger numbers increase priority to horizontal scanning early in the scanning process
		"search.LineHorizontalWeightAdjustment":
		[
			"value": Double(0.47),
			"public": true,
			"type": ValueType.Real.rawValue,
			"description": "Specifies the priority of scanning horizontal (offset) versus rotated (angle) search lines\n\nLarger numbers increase priority to horizontal scanning early in the scanning process"
		],

		// Specifies the rotational density of search lines, used to search for the deck in each frame of video.
		//
		// Search lines can be clustered near 90-degree orientations to accommodate for the higher likelihood of the deck being
		// either perfectly vertical or horizontal. Some clustering is recommended.
		//
		// A value of 1.0 would indicate no clustering with the number of rotational search lines (see `search.LineRotationSteps`)
		// being evenly distributed from 0-90 degrees. A value of 2.0 will distribute the search lines such that there are more
		// search lines near the 0-degree and 90-degree angles, with fewer near the 45-degree angle. Higher values increase this
		// clustering even more, but be careful - this is an exponential value.
		//
		// Generaly speaking, a value of 2.0 would provide moderate clustering, a value of 3.0 would provide a high amount of
		// clustering, with values of 4.0 and higher being exponentially increasing extremes.
		//
		// Note that there is an internal limit placed on the search lines, such that no two search lines can be too similar.
		// Therefore, extreme amounts of clustering would result in fewer search lines because the lines would be so clustered near
		// the 90-degree angles that they would be considered duplicates and filtered out.
		"search.LineRotationDensity":
		[
			"value": Double(3),
			"public": true,
			"type": ValueType.Real.rawValue,
			"description": "Specifies the rotational density of search lines, used to search for the deck in each frame of video. \n\nSearch lines can be clustered near 90-degree orientations to accommodate for the higher likelihood of the deck being either perfectly vertical or horizontal. Some clustering is recommended. \n\nA value of 1.0 would indicate no clustering with the number of rotational search lines (see `search.LineRotationSteps`) being evenly distributed from 0-90 degrees. A value of 2.0 will distribute the search lines such that there are more search lines near the 0-degree and 90-degree angles, with fewer near the 45-degree angle. Higher values increase this clustering even more, but be careful - this is an exponential value.\n\nGeneraly speaking, a value of 2.0 would provide moderate clustering, a value of 3.0 would provide a high amount of clustering, with values of 4.0 and higher being exponentially increasing extremes. \n\nNote that there is an internal limit placed on the search lines, such that no two search lines can be too similar. Therefore, extreme amounts of clustering would result in fewer search lines because the lines would be so clustered near the 90-degree angles that they would be considered duplicates and filtered out."
		],

		// Specifies the number of rotational search lines between the 0- and 90-degree rotations. For example, a value of 5 would
		// represent 5 rotations between 0 and 90.
		//
		// The search lines are not expected to be evenly distributed - see `search.LineRotationDensity` for more information.
		//
		// Note that there is an internal limit placed on the search lines, such that no two search lines can be too similar.
		// Therefore, extreme amounts of clustering would result in fewer search lines because the lines would be so clustered near
		// the 90-degree angles that they would be considered duplicates and filtered out.
		//
		// Also note that higher larger numbers cause initial searches to take longer, which could cause more battery use.
		"search.LineRotationSteps":
		[
			"value": Double(8),
			"public": true,
			"type": ValueType.Real.rawValue,
			"description": "Specifies the number of rotational search lines between the 0- and 90-degree rotations. For example, a value of 5 would represent 5 rotations between 0 and 90. \n\nThe search lines are not expected to be evenly distributed - see `search.LineRotationDensity` for more information. \n\nNote that there is an internal limit placed on the search lines, such that no two search lines can be too similar. Therefore, extreme amounts of clustering would result in fewer search lines because the lines would be so clustered near the 90-degree angles that they would be considered duplicates and filtered out. \n\nAlso note that higher larger numbers cause initial searches to take longer, which could cause more battery use."
		],

		// Search lines will not exist with a smaller angle than this value (relative to the horizontal direction of a video
		// frame.) This value probably shouldn't be set to anything smaller than 0.
		"search.LineMinAngleCutoff":
		[
			"value": Double(-30),
			"public": true,
			"type": ValueType.Real.rawValue,
			"description": "Search lines will not exist with a smaller angle than this value (relative to the horizontal direction of a video frame.) This value probably shouldn't be set to anything smaller than 0."
		],

		// Search lines will not exist with a larger angle than this value (relative to the horizontal direction of a video
		// frame.) This value probably should be set to anything larger than 90.
		"search.LineMaxAngleCutoff":
		[
			"value": Double(30),
			"public": true,
			"type": ValueType.Real.rawValue,
			"description": "Search lines will not exist with a larger angle than this value (relative to the horizontal direction of a video frame.)This value probably should be set to anything larger than 90."
		],

		// Scales the search line offset. Generally, this should be a value from 0..1. A value of 0.5 would limit the search lines
		// to within half the distance from the center to the widest dimension of the screen.
		"search.LineLinearLimitScalar":
		[
			"value": Double(1),
			"public": true,
			"type": ValueType.Real.rawValue,
			"description": "Scales the search line offset. Generally, this should be a value from 0..1. A value of 0.5 would limit the search lines to within half the distance from the center to the widest dimension of the screen."
		],

		// Specifies the linear density of search lines, used to search for the deck in each frame of video.
		//
		// Search lines can be clustered near the origin (i.e., the last known place where the deck was found, or the center of the
		// frame of video if no deck has been found recently.) This is to account for for the higher likelihood of the deck being
		// close to where it was last found or near the center of the frame. Some clustering is recommended.
		//
		// A value of 1.0 would indicate no clustering with the number of search lines (see `search.LineLinearSteps`) being evenly
		// distributed through the image. A value of 2.0 will distribute the search lines such that there are more near the origin,
		// with fewer search lines spreading out from the origin. Higher values increase this clustering even more, but be careful -
		// this is an exponential value.
		//
		// Generaly speaking, a value of 2.0 would provide moderate clustering, a value of 3.0 would provide a high amount of
		// clustering, with values of 4.0 and higher being exponentially increasing extremes.
		//
		// Note that there is an internal limit placed on the search lines, such that no two search lines can be too similar.
		// Therefore, extreme amounts of clustering would result in fewer search lines because the lines would be so clustered near
		// the origin that they would be considered duplicates and filtered out.
		"search.LineLinearDensity":
		[
			"value": Double(3),
			"public": true,
			"type": ValueType.Real.rawValue,
			"description": "Specifies the linear density of search lines, used to search for the deck in each frame of video. \n\nSearch lines can be clustered near the origin (i.e., the last known place where the deck was found, or the center of the frame of video if no deck has been found recently.) This is to account for for the higher likelihood of the deck being close to where it was last found or near the center of the frame. Some clustering is recommended. \n\nA value of 1.0 would indicate no clustering with the number of search lines (see `search.LineLinearSteps`) being evenly distributed through the image. A value of 2.0 will distribute the search lines such that there are more near the origin, with fewer search lines spreading out from the origin. Higher values increase this clustering even more, but be careful - this is an exponential value. \n\nGeneraly speaking, a value of 2.0 would provide moderate clustering, a value of 3.0 would provide a high amount of clustering, with values of 4.0 and higher being exponentially increasing extremes. \n\nNote that there is an internal limit placed on the search lines, such that no two search lines can be too similar. Therefore, extreme amounts of clustering would result in fewer search lines because the lines would be so clustered near the origin that they would be considered duplicates and filtered out."
		],

		// Specifies the number of search lines between spreading out from the origin of the search grid.. For example, a value of
		// 5 would represent 5 search lines to cover the area from the origin to the height or width of the video image.
		//
		// The search lines are not expected to be evenly distributed - see `search.LineLinearDensity` for more information.
		//
		// Note that there is an internal limit placed on the search lines, such that no two search lines can be too similar.
		// Therefore, extreme amounts of clustering would result in fewer search lines because the lines would be so clustered near
		// the origin that they would be considered duplicates and filtered out.
		//
		// Also note that higher larger numbers cause initial searches to take longer, which could cause more battery use.
		"search.LineLinearSteps":
		[
			"value": Double(8),
			"public": true,
			"type": ValueType.Real.rawValue,
			"description": "Specifies the number of search lines between spreading out from the origin of the search grid.. For example, a value of 5 would represent 5 search lines to cover the area from the origin to the height or width of the video image. \n\nThe search lines are not expected to be evenly distributed - see `search.LineLinearDensity` for more information. \n\nNote that there is an internal limit placed on the search lines, such that no two search lines can be too similar. Therefore, extreme amounts of clustering would result in fewer search lines because the lines would be so clustered near the origin that they would be considered duplicates and filtered out. \n\nAlso note that higher larger numbers cause initial searches to take longer, which could cause more battery use."
		],

		// If true, a set of bi-directional search lines will be generated, capable of locating decks that are upside-down in
		// frame. Note that if the deck format is marked as reversible, bidirectional searches are disabled.
		"search.LineBidirectional":
		[
			"value": Bool(true),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "If true, a set of bi-directional search lines will be generated, capable of locating decks that are upside-down in frame."
		],

		// The name of the code definition to search for
		"search.CodeDefinition":
		[
			"value": "mds12-54",
			"public": true,
			"type": ValueType.CodeDefinition.rawValue,
			"description": "The name of the code definition to search for"
		],

		// Performs interpolation along MarkLines using the contour of the bit-neighboring LandMarks rather than
		// the top/bottom line
		"search.UseLandmarkContours":
		[
			"value": Bool(true),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Performs interpolation along MarkLines using the contour of the bit-neighboring LandMarks rather than the top/bottom line"
		],

		// Do not match decks with this much (or more) error
		"search.MaxDeckMatchError":
		[
			"value": Double(1.3),
			"public": true,
			"type": ValueType.Real.rawValue,
			"description": "Do not match decks with this much (or more) error"
		],

		// Rolling min/max window size multiplier (relative to the rolling average window size) used for edge detection when
		// searching for the deck
		//
		// For details, see EdgeDetection.detectEdges
		//
		// The rolling average window size is calculated by the narrowest landmark. This value is a multiple of that calculated
		// rolling window size in order to provide an overall min/max of the pixels around that window. If the rolling average
		// window is calculated as being 13 and the multiplier is 6, then the final min/max rolling window size would be 78.
		"search.EdgeDetectionDeckRollingMinMaxWindowMultiplier":
		[
			"value": Double(6.77),
			"public": true,
			"type": ValueType.Real.rawValue,
			"description": "Rolling min/max window size multiplier (relative to the rolling average window size) used for edge detection when searching for the deck\n\nFor details, see EdgeDetection.detectEdges\n\nThe rolling average window size is calculated by the narrowest landmark. This value is a multiple of that calculated rolling window size in order to provide an overall min/max of the pixels around that window. If the rolling average window is calculated as being 13 and the multiplier is 6, then the final min/max rolling window size would be 78."
		],

		// Rolling average overlap used for edge detection when searching for the deck
		//
		// For details, see EdgeDetection.detectEdges
		"search.EdgeDetectionDeckPeakRollingAverageOverlap":
		[
			"value": Int(0),
			"public": true,
			"type": ValueType.Integer.rawValue,
			"description": "Rolling average overlap used for edge detection when searching for the deck\n\nFor details, see EdgeDetection.detectEdges"
		],

		// Edge sensitivity used for edge detection when searching for the deck
		//
		// For details, see EdgeDetection.detectEdges
		"search.EdgeDetectionDeckEdgeSensitivity":
		[
			"value": Double(0.2),
			"public": true,
			"type": ValueType.FixedPoint.rawValue,
			"description": "Edge sensitivity used for edge detection when searching for the deck\n\nFor details, see EdgeDetection.detectEdges"
		],

		// Edge sensitivity used for tracing landmarks
		//
		// This value represents the sensitivity of detecting the top/bottom edge of Landmarks in the deck in order to determine the
		// top/bottom edges of the deck. This value ranges from [0,1] with smaller increasing sensitivity. Be careful with this, as
		// the ratio being used here will trend above 0.5.
		"search.TraceMarksEdgeSensitivity":
		[
			"value": Double(0.6),
			"public": true,
			"type": ValueType.FixedPoint.rawValue,
			"description": "Edge sensitivity used for tracing landmarks\n\nThis value represents the sensitivity of detecting the top/bottom edge of Landmarks in the deck in order to determine the top/bottom edges of the deck. This value ranges from [0,1] with smaller increasing sensitivity. Be careful with this, as the ratio being used here will trend above 0.5."
		],

		// Amount a trace mark is allowed to stray from center, allowing for imperfectly squared decks.
		//
		// This value represents a ratio of the width of a mark. A value of 0.5 allows a stray of half the width of the mark.
		// A value of 1.0 would allow the mark to stray its full width.
		//
		// Note that this value is dependent upon the width of the traced mark.
		"search.TraceMarksMaxStray":
		[
			"value": Double(0.5),
			"public": true,
			"type": ValueType.FixedPoint.rawValue,
			"description": "Amount a trace mark is allowed to stray from center, allowing for imperfectly squared decks.\n\nThis value represents a ratio of the width of a mark. A value of 0.5 allows a stray of half the width of the mark. A value of 1.0 would allow the mark to stray its full width.\n\nNote that this value is dependent upon the width of the traced mark."
		],

		// Temporal coherence tracks the deck in the frame. If our temporal state is older than this, it is
		// considered to be expired.
		"search.TemporalExpirationMS":
		[
			"value": Double(200.0),
			"public": true,
			"type": ValueType.Time.rawValue,
			"description": "Temporal coherence tracks the deck in the frame. If our temporal state is older than this, it is con sidered to be expired."
		],

		// Do not use this value directly - instead, use `kMaxEdgeTraceMisses`
		"search.BaseMaxEdgeTraceMisses":
		[
			"value": Int(5),
			"public": true,
			"type": ValueType.Integer.rawValue,
			"description": "Do not use this value directly - instead, use `kMaxEdgeTraceMisses`"
		],

		// How much to backup (after reaching an extent) in order to find extents with higher detail
		"search.TraceMarkBackupDistance":
		[
			"value": Int(10),
			"public": true,
			"type": ValueType.Integer.rawValue,
			"description": "How much to backup (after reaching an extent) in order to find extents with higher detail"
		],

		// If a deck is not found within the period of time specified by `search.BatterySaverStartMS`, the battery saver is
		// initiated.
		//
		// During battery saver scanning is performed for one frame every `search.BatterySaverIntervalMS` milliseconds until a deck
		// is found, at which point battery saver is disabled again.
		"search.BatterySaverStartMS":
		[
			"value": Int(150000),
			"public": true,
			"type": ValueType.Integer.rawValue,
			"description": "If a deck is not found within the period of time specified by `search.BatterySaverStartMS`, the battery saver is initiated. \n\nDuring battery saver scanning is performed for one frame every `search.BatterySaverIntervalMS` milliseconds until a deck is found, at which point battery saver is disabled again."
		],

		// If a deck is not found within the period of time specified by `search.BatterySaverStartMS`, the battery saver is
		// initiated.
		//
		// During battery saver scanning is performed for one frame every `search.BatterySaverIntervalMS` milliseconds until a deck
		// is found, at which point battery saver is disabled again.
		"search.BatterySaverIntervalMS":
		[
			"value": Int(250),
			"public": true,
			"type": ValueType.Integer.rawValue,
			"description": "If a deck is not found within the period of time specified by `search.BatterySaverStartMS`, the battery saver is initiated. \n\nDuring battery saver scanning is performed for one frame every `search.BatterySaverIntervalMS` milliseconds until a deck is found, at which point battery saver is disabled again."
		],

		// Enables sharpness detection, which is used to determine if a frame is worth attempting to decode.
		//
		// Frames that are not sharp enough for reliable decoding can pollute the history. Therefore, decoding and the
		// subsequent history pollution can be avoided if the frame is determined to be out of focus.
		//
		// A possible caveat to this is that codes that use error correction can reducde the need for sharpness detection.
		// In fact, a frame that might be out of focus could potentially be decoded using error correction. This reduces the
		// number of frames needed (i.e., shortens the time) for the confident result.
		"decode.EnableSharpnessDetection":
		[
			"value": Bool(true),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enables sharpness detection, which is used to determine if a frame is worth attempting to decode.\n\nFrames that are not sharp enough for reliable decoding can pollute the history. Therefore, decoding and the subsequent history pollution can be avoided if the frame is determined to be out of focus.\n\nA possible caveat to this is that codes that use error correction can reducde the need for sharpness detection. In fact, a frame that might be out of focus could potentially be decoded using error correction. This reduces the number of frames needed (i.e., shortens the time) for the confident result."
		],

		// Before attempting to decode a deck, the mark lines are used to perform sharpness calculations from
		// sets of samples in the image data where the bits are known to be. These values represent the average across all
		// mark lines maximum sharpness unit scalar values. If that calculated average falls below this threshold will not be
		// scanned as they are assumed to be too blurry to scan reliably.
		//
		// This value is only use if decode.EnableSharpnessDetection is also enabled.
		//
		// A value of 0 represents a deck that is fully blurred, while a value of 1.0 represents a deck that is in perfect
		// sharpness.
		"decode.MinimumSharpnessUnitScalarThreshold":
		[
			"value": Double(0.7),
			"public": true,
			"type": ValueType.FixedPoint.rawValue,
			"description": "Before attempting to decode a deck, the mark lines are used to perform sharpness calculations from sets of samples in the image data where the bits are known to be. These values represent the average across all mark lines maximum sharpness unit scalar values. If that calculated average falls below this threshold will not be scanned as they are assumed to be too blurry to scan reliably.\n\nThis value is only use if decode.EnableSharpnessDetection is also enabled.\n\nA value of 0 represents a deck that is fully blurred, while a value of 1.0 represents a deck that is in perfect sharpness."
		],

		// Bit columns, when resampled, are resampled to this multiple of the maximum deck card count
		"decode.ResampleBitColumnLengthMultiplier":
		[
			"value": Double(5),
			"public": true,
			"type": ValueType.FixedPoint.rawValue,
			"description": "Bit columns, when resampled, are resampled to this multiple of the maximum deck card count"
		],

		// Denotes the relative intensity of a printed mark in order to be detected. Based on the min/max range of a column of
		// printed marks, a value of 0.5 will use the center of the min/max range as the threshold. Smaller values (toward 0.0)
		// will require more intense marks (Black under normal and IR light, bright under UV). Larger values (toward 1.0) will
		// allow for less intense marks.
		//
		// A good starting point is 0.5
		"decode.MarkLineAverageOffsetMultiplier":
		[
			"value": Double(0.5),
			"public": true,
			"type": ValueType.FixedPoint.rawValue,
			"description": "Denotes the relative intensity of a printed mark in order to be detected. Based on the min/max range of a column of printed marks, a value of 0.5 will use the center of the min/max range as the threshold. Smaller values (toward 0.0) will require more intense marks (Black under normal and IR light, bright under UV). Larger values (toward 1.0) will allow for less intense marks.\n\nA good starting point is 0.5."
		],

		// The Genocide challenge compares two non-overlapping instances of a card to decide if one card's
		// instance should simply go away. This is effectively throwing away a card's instance, assuming it is simply wrong.
		// This should be a high-confidence challenge. To that end, we don't simply compare the raw counts.
		// Rather, we scale the smaller count up by a scale factor and if the larger count is still greater than the smaller
		// count, the instance with the greater count is considered the clear winner of the challenge.
		//
		// This value should be chosen carefully. Under normal circumstances, using properly encoded cards with high
		// Hamming distances, the need for a Genocide challenge should be very rare as it should only arise if a card is
		// mis-read as a different card. Therefore, if a challenge does arise, there should be a great difference between
		// the mis-read instance and the actual.
		//
		// Setting this value to less than 1.0 or less will always return a clear winner to the instance with the higher
		// count. As this value increases above 1.0, the challenge becomes more difficult. This is a good thing, as this
		// increases the confidence of the challenge. However, setting this value too high can provide a confidence level
		// that is impossible to obtain causing all challenges to fail and resulting in duplicate cards returned in the set.
		"resolve.GenocideScaleFactor":
		[
			"value": Double(1), // 1 is a better value for 6bit Interleaved
			"public": true,
			"type": ValueType.FixedPoint.rawValue,
			"description": "The Genocide challenge compares two non-overlapping instances of a card to decide if one card's instance should simply go away. This is effectively throwing away a card's instance, assuming it is simply wrong. This should be a high-confidence challenge. To that end, we don't simply compare the raw counts. Rather, we scale the smaller count up by a scale factor and if the larger count is still greater than the smaller count, the instance with the greater count is considered the clear winner of the challenge.\n\nThis value should be chosen carefully. Under normal circumstances, using properly encoded cards with high Hamming distances, the need for a Genocide challenge should be very rare as it should only arise if a card is mis-read as a different card. Therefore, if a challenge does arise, there should be a great difference between the mis-read instance and the actual.\n\nSetting this value to less than 1.0 or less will always return a clear winner to the instance with the higher count. As this value increases above 1.0, the challenge becomes more difficult. This is a good thing, as this increases the confidence of the challenge. However, setting this value too high can provide a confidence level that is impossible to to obtain causing all challenges to fail and resulting in duplicate cards returned in the set."
		],

		// Minimum number of samples per card edge
		//
		// A test value of 2.0 is seriously challenging
		//
		// A value of 2.5 is nice, but limiting
		//
		// I generally tend to stick with 2.2.
		"deck.MinSamplesPerCard":
		[
			"value": Double(2.0),
			"public": true,
			"type": ValueType.Real.rawValue,
			"description": "Minimum number of samples per card edge\n\nA test value of 2.0 is seriously challenging\n\nA value of 2.5 is nice, but limiting\n\nI generally tend to stick with 2.2."
		],

		// History analysis includes a process to find missing cards by analyzing historic entries to find those that contain the
		// card. If enough entries contain the missing card, it is added to the remaining historic entries where the card was
		// missed. This value represents a ratio of the total history entries that must contain the card in order for it to be
		// considered truly found.
		"analysis.MissingCardPopularity":
		[
			"value": Double(0.5),
			"public": true,
			"type": ValueType.FixedPoint.rawValue,
			"description": "History analysis includes a process to find missing cards by analyzing historic entries to find those that contain the card. If enough entries contain the missing card, it is added to the remaining historic entries where the card was missed. This value represents a ratio of the total history entries that must contain the card in order for it to be considered truly found."
		],

		// Max history age for recent results. This value is used to determine how much time we have to collect
		// our minimum number of history entries (see minHistoryEntries)
		//
		// Larger values here will allow more time to collect historic results. Having enough historic results is important
		// because these are the data points used by the statistical analysis for determining probabilistic correctness.
		//
		// The drawback to larger values is that it will take longer to build up enough history to satisfy
		// `minHistoryEntries` in order to begin returning results. In addition to this, when a new deck begins scanning,
		// it will take time for old history values to purge the system enough for the new deck to be considered correct.
		"analysis.MaxHistoryAgeMS":
		[
			"value": Int(4000),
			"public": true,
			"type": ValueType.Integer.rawValue,
			"description": "Max history age for recent results. This value is used to determine how much time we have to collect our minimum number of history entries (see minHistoryEntries)\n\nLarger values here will allow more time to collect historic results. Having enough historic results is important because these are the data points used by the statistical analysis for determining probabilistic correctness.\n\nThe drawback to larger values is that it will take longer to build up enough history to satisfy `minHistoryEntries` in order to begin returning results. In addition to this, when a new deck begins scanning, it will take time for old history values to purge the system enough for the new deck to be considered correct."
		],

		// The amount of historic entries represents the number of data points available to determine the
		// correctness of a result. More data points will increase our overall confidence. Therefore, this value plays a key
		// role in our ability to determine if a result is probabilistically correct.
		"analysis.MinHistoryEntries":
		[
			"value": Int(15),
			"public": true,
			"type": ValueType.Integer.rawValue,
			"description": "The amount of historic entries represents the number of data points available to determine the correctness of a result. More data points will increase our overall confidence. Therefore, this value plays a key role in our ability to determine if a result is probabilistically correct."
		],

		// Threshold for the minimum confidence required to consider a scan to be correct.
		//
		// Confidence factors range from 0.0 to 100.0.
		"analysis.MinimumConfidenceFactorThreshold":
		[
			"value": Double(70),
			"public": true,
			"type": ValueType.Real.rawValue,
			"description": "Threshold for the minimum confidence required to consider a scan to be correct.\n\nConfidence factors range from 0.0 to 100.0."
		],

		// Threshold for the a confidence factor to be considered as being high confidence
		//
		// Confidence factors range from 0.0 to 100.0.
		"analysis.HighConfidenceFactorThreshold":
		[
			"value": Double(90),
			"public": true,
			"type": ValueType.Real.rawValue,
			"description": "Threshold for the a confidence factor to be considered as being high confidence\n\nConfidence factors range from 0.0 to 100.0."
		],

		// Low-confidence reporting flag
		//
		// Scan reports include information related to confidence - a confidence factor (from 0->infinity) as well as a
		// flag determining if a report is low confidence or high confidence (see 'analysisMinimumConfidenceFactorThreshold'
		// and 'analysisHighConfidenceFactorThreshold'.)
		//
		// This flag enables the delivery of low-confidence reports. Setting it to `false` will cause low-confidence
		// reports to be ignored and only high-confidence reports will be delivered.
		//
		// Low-confidence reports can provide some value. They can provide reports when poor conditions reduce the ability
		// to provide high-confidence reports. Also, it can take time to build enough history for a high-confidence
		// report, which means that low- confidence reports can provide quicker results.
		"analysis.EnableLowConfidenceReports":
		[
			"value": Bool(true),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Low-confidence reporting flag\n\nScan reports include information related to confidence - a confidence factor (from 0->infinity) as well as a flag determining if a report is low confidence or high confidence (see 'analysisMinimumConfidenceFactorThreshold' and 'analysisHighConfidenceFactorThreshold'.)\n\nThis flag enables the delivery of low-confidence reports. Setting it to `false` will cause low-confidence reports to be ignored and only high-confidence reports will be delivered.\n\nLow-confidence reports can provide some value. They can provide reports when poor conditions reduce the ability to provide high-confidence reports."
		],

		// The camera's capture width
		"capture.FrameWidth":
		[
			"value": Int(1920),
			"public": true,
			"type": ValueType.Integer.rawValue,
			"description": "The camera's capture width"
		],

		// The camera's capture height
		"capture.FrameHeight":
		[
			"value": Int(1080),
			"public": true,
			"type": ValueType.Integer.rawValue,
			"description": "The camera's capture height"
		],

		// The camera's capture rate in frames per second
		"capture.FrameRateHz":
		[
			"value": Int(30),
			"public": true,
			"type": ValueType.Integer.rawValue,
			"description": "The camera's capture rate in frames per second"
		],

		// If this value is greater than zero, a video thumbnail will be sent to wifi clients every `ViewportFrequencyFrames`
		// frames.
		"capture.ViewportFrequencyFrames":
		[
			"value": Int(2),
			"public": true,
			"type": ValueType.Integer.rawValue,
			"description": "If this value is greater than zero, a video thumbnail will be sent to wifi clients every `ViewportFrequencyFrames` frames."
		],

		// Specifies the type of viewport to send. Possible values are one of:
		//
		//     0 (.LumaResampledToViewportSize): Luminance image resampled to viewport size
		//     1 (.LumaCenterViewportRect): Center portion of luminance image of viewport size (useful for checking focus)
		//
		// If an unsupported value is provided, `0` should be used
		//
		// See `capture.ViewportFrequencyFrames` to ensure that the viewport is enabled.
		"capture.ViewportType":
		[
			"value": Int(ViewportMessage.ViewportType.LumaResampledToViewportSize.rawValue),
			"public": true,
			"type": ValueType.Integer.rawValue,
			"description": "Specifies the type of viewport to send. Possible values are one of:\n\n     0 (.LumaResampledToViewportSize): Luminance image resampled to viewport size\n     1 (.LumaCenterViewportRect): Center portion of luminance image of viewport size (useful for checking focus)\n\nIf an unsupported value is provided, `0` should be used\n\nSee `capture.ViewportFrequencyFrames` to ensure that the viewport is enabled."
		],

		// Enable drawing the video output to the testbed viewport.
		//
		// Note that for this to work, debug.ViewportDebugView also needs to be enabled.
		"testbed.DrawViewport":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable drawing the video output to the testbed viewport.\n\nNote that for this to work, debug.ViewportDebugView also needs to be enabled."
		],

		// Disables output interpolation (faster and more sample-accurate, but bad for detailed debug info on
		// high-rez images)
		"testbed.ViewInterpolation":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Disables output interpolation (faster and more sample-accurate, but bad for detailed debug info on high-rez images)"
		],

		// Enable/disable histogram normalization on the input video
		"testbed.FilterInputHistogramNormalization":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable/disable histogram normalization on the input video"
		],

		// Enable/disable contrast enhancement on the input video
		"testbed.FilterInputContrastEnhance":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable/disable contrast enhancement on the input video"
		],

		// Enable/disable a hack-map on the input video (this is generally used to test out various hacks at
		// various times)
		"testbed.FilterInputHackMap":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable/disable a hack-map on the input video (this is generally used to test out various hacks at various times)"
		],

		// Enable/disable a box filter on the input video
		"testbed.FilterInputBoxFilter":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable/disable a box filter on the input video"
		],

		// Enable/disable a low-pass filter on the input video
		"testbed.FilterInputLowPass":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable/disable a low-pass filter on the input video"
		],

		// Enable drawing the sharpness graphs above all SampleLines where it is calculated (see decode.EnableSharpnessDetection)
		"debug.DrawSharpnessGraphs":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable drawing the sharpness graphs above all SampleLines where it is calculated (see decode.EnableSharpnessDetection)"
		],

		// Enable to draw lines that were searched
		"debug.DrawSearchedLines":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw lines that were searched"
		],

		// Enable to draw DeckLocations that were found
		"debug.DrawMatchedDeckLocations":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw DeckLocations that were found"
		],

		// Enable to draw DeckLocations that were discarded
		"debug.DrawMatchedDeckLocationDiscards":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw DeckLocations that were discarded"
		],

		// Enable to draw histogram of the mark widths
		"debug.DrawMarkHistogram":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw histogram of the mark widths"
		],

		// Enable to draw histogram of the bit pattern usage
		"debug.DrawBitPatternHistogram":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw histogram of the bit pattern usage"
		],

		// Enable to draw DeckMatchResults for found decks
		"debug.DrawDeckMatchResults":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw DeckMatchResults for found decks"
		],

		// Enable to draw all marks found, not just those that result in a MatchResult
		"debug.DrawAllMarks":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw all marks found, not just those that result in a MatchResult"
		],

		// Enable to draw markers that represent bit ranges in the found deck
		"debug.DrawMarkLines":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw markers that represent bit ranges in the found deck"
		],

		// Enable to draw the full search grid
		"debug.DrawFullSearchGrid":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw the full search grid"
		],

		// Enable to draw the line order sequentially in order to view search ordering
		"debug.DrawSequentialSearchLineOrder":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw the line order sequentially in order to view search ordering"
		],

		// Causes the detected image edges to be drawn
		"debug.DrawEdges":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Causes the detected image edges to be drawn"
		],

		// Enable to draw edge detection detail charts along the lines where the edges detected (using
		// sequencing to select the edge)
		"debug.DrawSequencedEdgeDetection":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw edge detection detail charts along the lines where the edges detected (using sequencing to select the edge)"
		],

		// Enable to draw edge detection detail charts along the lines where the edges detected (using the
		// mouse drag to select the edge)
		"debug.DrawMouseEdgeDetection":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw edge detection detail charts along the lines where the edges detected (using the mouse drag to select the edge)"
		],

		// Enable to draw the deck extents (top/bottom lines of the deck)
		"debug.DrawDeckExtents":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw the deck extents (top/bottom lines of the deck)"
		],

		// Enable to draw the trace marks (tracing landmarks to find deck extents)
		"debug.DrawTraceMarks":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw the trace marks (tracing landmarks to find deck extents)"
		],

		// Enable to draw the scanning results (the outlines on the image frame)
		"debug.DrawScanResults":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Enable to draw the scanning results (the outlines on the image frame)"
		],

		// Localized breakpoint that can be triggered by a key press (see checkBreakpoint())
		"debug.BreakpointEnabled":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Localized breakpoint that can be triggered by a key press (see checkBreakpoint())"
		],

		// Causes the processing to pause as soon as we find and process a deck
		"debug.PauseOnIncorrectDecode":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Causes the processing to pause as soon as we find and process a deck"
		],

		// Causes the processing to pause as soon as we fail to find a deck
		"debug.PauseOnCorrectDecode":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Causes the processing to pause as soon as we fail to find a deck"
		],

		// Causes the input video to be rotated by 180 degrees to test upside-down inputs
		"debug.RotateFrame":
		[
			"value": Bool(false),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Causes the input video to be rotated by 180 degrees to test upside-down inputs"
		],

		// Causes the results to be validated (for internal debug use only)
		"debug.ValidateResults":
		[
			"value": Bool(false),
			"public": false,
			"type": ValueType.Boolean.rawValue,
			"description": "Causes the results to be validated (for internal debug use only)"
		],

		// Specifies if the viewport should be based on the debug buffer.
		//
		// See `capture.ViewportFrequencyFrames` to ensure that the viewport is enabled.
		"debug.ViewportDebugView":
		[
			"value": Bool(true),
			"public": true,
			"type": ValueType.Boolean.rawValue,
			"description": "Specifies if the viewport should be based on the debug buffer.\n\nSee `capture.ViewportFrequencyFrames` to ensure that the viewport is enabled."
		]
	]

	// -----------------------------------------------------------------------------------------------------------------------------
	//   ____      _   _                    ___      ____       _   _
	//  / ___| ___| |_| |_ ___ _ __ ___    ( _ )    / ___|  ___| |_| |_ ___ _ __ ___
	// | |  _ / _ \ __| __/ _ \ '__/ __|   / _ \/\  \___ \ / _ \ __| __/ _ \ '__/ __|
	// | |_| |  __/ |_| ||  __/ |  \__ \  | (_>  <   ___) |  __/ |_| ||  __/ |  \__ \
	//  \____|\___|\__|\__\___|_|  |___/   \___/\/  |____/ \___|\__|\__\___|_|  |___/
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	public static func getString(_ name: String) -> String
	{
		return configDict[name]?["value"] as? String ?? ""
	}

	public static func setString(_ name: String, withValue value: String)
	{
		configDict[name]?["value"] = value
		notify(name)
	}

	public static func getPath(_ name: String) -> PathString
	{
		return PathString(configDict[name]?["value"] as? String ?? "")
	}

	public static func setPath(_ name: String, withValue value: PathString)
	{
		configDict[name]?["value"] = value.toString()
		notify(name)
	}

	public static func getCodeDefinition(_ inName: String, fromCache: Bool = false) -> CodeDefinition?
	{
		let name = configDict[inName]?["value"] as? String ?? ""
		guard let codeDefinition = CodeDefinition.findCodeDefinition(byName: name) else
		{
			if !fromCache
			{
				// We never found a code definition - provide some useful log output
				var cdArray = [String]()
				cdArray.append("Unable to find configured code definition ('\(name)')")
				cdArray.append("  For reference, here are the available code definitions")
				cdArray.append("  {")
				for codeDefinition in CodeDefinition.codeDefinitions
				{
					cdArray.append("    \"\(codeDefinition.format.name)\"")
				}
				cdArray.append("  }")
				gLogger.error(cdArray.joined(separator: "\n"))
			}
			return nil
		}

		return codeDefinition
	}

	public static func setCodeDefinition(_ name: String, withValue value: CodeDefinition?)
	{
		configDict[name]?["value"] = value?.format.name ?? "- none -"
		notify(name)
	}

	public static func getPathArray(_ name: String) -> [PathString]
	{
		let strings = configDict[name]?["value"] as? [String] ?? []
		var paths = [PathString]()
		for string in strings
		{
			paths.append(PathString(string))
		}
		return paths
	}

	public static func setPathArray(_ name: String, withValue value: [PathString])
	{
		var strings = [String]()
		for path in value
		{
			strings.append(path.toString())
		}
		configDict[name]?["value"] = strings
		notify(name)
	}

	public static func getStringMap(_ name: String) -> [String: String]
	{
		return configDict[name]?["value"] as? [String: String] ?? [:]
	}

	public static func setStringMap(_ name: String, withValue value: [String: String])
	{
		configDict[name]?["value"] = value
		notify(name)
	}

	public static func getBool(_ name: String) -> Bool
	{
		return configDict[name]?["value"] as? Bool ?? false
	}

	public static func setBool(_ name: String, withValue value: Bool)
	{
		configDict[name]?["value"] = value
		notify(name)
	}

	public static func getInt(_ name: String) -> Int
	{
		if let result = configDict[name]?["value"] as? Int { return Int(result) }
		if let result = configDict[name]?["value"] as? Double { return Int(result) }
		return 0
	}

	public static func setInt(_ name: String, withValue value: Int)
	{
		configDict[name]?["value"] = value
		notify(name)
	}

	public static func getFixed(_ name: String) -> FixedPoint
	{
		if let result = configDict[name]?["value"] as? Double { return FixedPoint(result) }
		if let result = configDict[name]?["value"] as? Int { return FixedPoint(result) }
		return 0
	}

	public static func setFixed(_ name: String, withValue value: FixedPoint)
	{
		configDict[name]?["value"] = Double(value)
		notify(name)
	}

	public static func getReal(_ name: String) -> Real
	{
		if let result = configDict[name]?["value"] as? Real { return result }
		if let result = configDict[name]?["value"] as? Double { return Real(result) }
		if let result = configDict[name]?["value"] as? Int { return Real(result) }
		return 0
	}

	public static func setReal(_ name: String, withValue value: Real)
	{
		configDict[name]?["value"] = Double(value)
		notify(name)
	}

	public static func getRollValue(_ name: String) -> RollValue
	{
		if let result = configDict[name]?["value"] as? RollValue { return result }
		if let result = configDict[name]?["value"] as? Int { return RollValue(result) }
		if let result = configDict[name]?["value"] as? Double { return RollValue(result) }
		return 0
	}

	public static func setRollValue(_ name: String, withValue value: RollValue)
	{
		configDict[name]?["value"] = Int(value)
		notify(name)
	}

	public static func getTime(_ name: String) -> Time
	{
		if let result = configDict[name]?["value"] as? Time { return result }
		if let result = configDict[name]?["value"] as? Int { return Time(result) }
		if let result = configDict[name]?["value"] as? Double { return Time(result) }
		return 0
	}

	public static func setTime(_ name: String, withValue value: Time)
	{
		configDict[name]?["value"] = Double(value)
		notify(name)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	//  ____                            _              _
	// |  _ \ _ __ ___  _ __   ___ _ __| |_ _   _     / \   ___ ___ ___  ___ ___  ___  _ __ ___
	// | |_) | '__/ _ \| '_ \ / _ \ '__| __| | | |   / _ \ / __/ __/ _ \/ __/ __|/ _ \| '__/ __|
	// |  __/| | | (_) | |_) |  __/ |  | |_| |_| |  / ___ \ (_| (_|  __/\__ \__ \ (_) | |  \__ \
	// |_|   |_|  \___/| .__/ \___|_|   \__|\__, | /_/   \_\___\___\___||___/___/\___/|_|  |___/
	//                 |_|                  |___/
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	public static var logFileLocations: [PathString] { get { return _logFileLocations } set(x) { setPathArray("log.FileLocations", withValue: x); _logFileLocations = x } }
	public static var logResetOnStart: Bool { get { return _logResetOnStart } set(x) { setBool("log.ResetOnStart", withValue: x); _logResetOnStart = x } }
	public static var logMasks: [String: String] { get { return _logMasks } set(x) { setStringMap("log.Masks", withValue: x); _logMasks = x } }
	public static var diagnosticLumaFilePath: PathString { get { return _diagnosticLumaFilePath } set(x) { setPath("diagnostic.LumaFilePath", withValue: x); _diagnosticLumaFilePath = x } }
	public static var systemReservedDiskSpaceMB: Int { get { return _systemReservedDiskSpaceMB } set(x) { setInt("system.ReservedDiskSpaceMB", withValue: x); _systemReservedDiskSpaceMB = x } }
	public static var edgeMinimumThreshold: RollValue { get { return _edgeMinimumThreshold } set(x) { setRollValue("edge.MinimumThreshold", withValue: x); _edgeMinimumThreshold = x } }
	public static var searchLineHorizontalWeightAdjustment: Real { get { return _searchLineHorizontalWeightAdjustment } set(x) { setReal("search.LineHorizontalWeightAdjustment", withValue: x); _searchLineHorizontalWeightAdjustment = x } }
	public static var searchLineRotationDensity: Real { get { return _searchLineRotationDensity } set(x) { setReal("search.LineRotationDensity", withValue: x); _searchLineRotationDensity = x } }
	public static var searchLineRotationSteps: Real { get { return _searchLineRotationSteps } set(x) { setReal("search.LineRotationSteps", withValue: x); _searchLineRotationSteps = x } }
	public static var searchLineMinAngleCutoff: Real { get { return _searchLineMinAngleCutoff } set(x) { setReal("search.LineMinAngleCutoff", withValue: x); _searchLineMinAngleCutoff = x } }
	public static var searchLineMaxAngleCutoff: Real { get { return _searchLineMaxAngleCutoff } set(x) { setReal("search.LineMaxAngleCutoff", withValue: x); _searchLineMaxAngleCutoff = x } }
	public static var searchLineLinearLimitScalar: Real { get { return _searchLineLinearLimitScalar } set(x) { setReal("search.LineLinearLimitScalar", withValue: x); _searchLineLinearLimitScalar = x } }
	public static var searchLineLinearDensity: Real { get { return _searchLineLinearDensity } set(x) { setReal("search.LineLinearDensity", withValue: x); _searchLineLinearDensity = x } }
	public static var searchLineLinearSteps: Real { get { return _searchLineLinearSteps } set(x) { setReal("search.LineLinearSteps", withValue: x); _searchLineLinearSteps = x } }
	public static var searchLineBidirectional: Bool { get { return _searchLineBidirectional } set(x) { setBool("search.LineBidirectional", withValue: x); _searchLineBidirectional = x } }
	public static var searchCodeDefinition: CodeDefinition? { get { return _searchCodeDefinition } set(x) { setCodeDefinition("search.CodeDefinition", withValue: x); _searchCodeDefinition = x } }
	public static var searchUseLandmarkContours: Bool { get { return _searchUseLandmarkContours } set(x) { setBool("search.UseLandmarkContours", withValue: x); _searchUseLandmarkContours = x } }
	public static var searchMaxDeckMatchError: Real { get { return _searchMaxDeckMatchError } set(x) { setReal("search.MaxDeckMatchError", withValue: x); _searchMaxDeckMatchError = x } }
	public static var searchEdgeDetectionDeckRollingMinMaxWindowMultiplier: Real { get { return _searchEdgeDetectionDeckRollingMinMaxWindowMultiplier } set(x) { setReal("search.EdgeDetectionDeckRollingMinMaxWindowMultiplier", withValue: x); _searchEdgeDetectionDeckRollingMinMaxWindowMultiplier = x } }
	public static var searchEdgeDetectionDeckPeakRollingAverageOverlap: Int { get { return _searchEdgeDetectionDeckPeakRollingAverageOverlap } set(x) { setInt("search.EdgeDetectionDeckPeakRollingAverageOverlap", withValue: x); _searchEdgeDetectionDeckPeakRollingAverageOverlap = x } }
	public static var searchEdgeDetectionDeckEdgeSensitivity: FixedPoint { get { return _searchEdgeDetectionDeckEdgeSensitivity } set(x) { setFixed("search.EdgeDetectionDeckEdgeSensitivity", withValue: x); _searchEdgeDetectionDeckEdgeSensitivity = x } }
	public static var searchTraceMarksEdgeSensitivity: FixedPoint { get { return _searchTraceMarksEdgeSensitivity } set(x) { setFixed("search.TraceMarksEdgeSensitivity", withValue: x); _searchTraceMarksEdgeSensitivity = x } }
	public static var searchTraceMarksMaxStray: FixedPoint { get { return _searchTraceMarksMaxStray } set(x) { setFixed("search.TraceMarksMaxStray", withValue: x); _searchTraceMarksMaxStray = x } }
	public static var searchTemporalExpirationMS: Time { get { return _searchTemporalExpirationMS } set(x) { setTime("search.TemporalExpirationMS", withValue: x); _searchTemporalExpirationMS = x } }
	public static var searchBaseMaxEdgeTraceMisses: Int { get { return _searchBaseMaxEdgeTraceMisses } set(x) { setInt("search.BaseMaxEdgeTraceMisses", withValue: x); _searchBaseMaxEdgeTraceMisses = x } }
	public static var searchTraceMarkBackupDistance: Int { get { return _searchTraceMarkBackupDistance } set(x) { setInt("search.TraceMarkBackupDistance", withValue: x); _searchTraceMarkBackupDistance = x } }
	public static var searchBatterySaverStartMS: Int { get { return _searchBatterySaverStartMS } set(x) { setInt("search.BatterySaverStartMS", withValue: x); _searchBatterySaverStartMS = x } }
	public static var searchBatterySaverIntervalMS: Int { get { return _searchBatterySaverIntervalMS } set(x) { setInt("search.BatterySaverIntervalMS", withValue: x); _searchBatterySaverIntervalMS = x } }
	public static var decodeEnableSharpnessDetection: Bool { get { return _decodeEnableSharpnessDetection } set(x) { setBool("decode.EnableSharpnessDetection", withValue: x); _decodeEnableSharpnessDetection = x } }
	public static var decodeMinimumSharpnessUnitScalarThreshold: FixedPoint { get { return _decodeMinimumSharpnessUnitScalarThreshold } set(x) { setFixed("decode.MinimumSharpnessUnitScalarThreshold", withValue: x); _decodeMinimumSharpnessUnitScalarThreshold = x } }
	public static var decodeResampleBitColumnLengthMultiplier: FixedPoint { get { return _decodeResampleBitColumnLengthMultiplier } set(x) { setFixed("decode.ResampleBitColumnLengthMultiplier", withValue: x); _decodeResampleBitColumnLengthMultiplier = x } }
	public static var decodeMarkLineAverageOffsetMultiplier: FixedPoint { get { return _decodeMarkLineAverageOffsetMultiplier } set(x) { setFixed("decode.MarkLineAverageOffsetMultiplier", withValue: x); _decodeMarkLineAverageOffsetMultiplier = x } }
	public static var resolveGenocideScaleFactor: FixedPoint { get { return _resolveGenocideScaleFactor } set(x) { setFixed("resolve.GenocideScaleFactor", withValue: x); _resolveGenocideScaleFactor = x } }
	public static var deckMinSamplesPerCard: Real { get { return _deckMinSamplesPerCard } set(x) { setReal("deck.MinSamplesPerCard", withValue: x); _deckMinSamplesPerCard = x } }
	public static var analysisMissingCardPopularity: FixedPoint { get { return _analysisMissingCardPopularity } set(x) { setFixed("analysis.MissingCardPopularity", withValue: x); _analysisMissingCardPopularity = x } }
	public static var analysisMaxHistoryAgeMS: Int { get { return _analysisMaxHistoryAgeMS } set(x) { setInt("analysis.MaxHistoryAgeMS", withValue: x); _analysisMaxHistoryAgeMS = x } }
	public static var analysisMinHistoryEntries: Int { get { return _analysisMinHistoryEntries } set(x) { setInt("analysis.MinHistoryEntries", withValue: x); _analysisMinHistoryEntries = x } }
	public static var analysisMinimumConfidenceFactorThreshold: Real { get { return _analysisMinimumConfidenceFactorThreshold } set(x) { setReal("analysis.MinimumConfidenceFactorThreshold", withValue: x); _analysisMinimumConfidenceFactorThreshold = x } }
	public static var analysisHighConfidenceFactorThreshold: Real { get { return _analysisHighConfidenceFactorThreshold } set(x) { setReal("analysis.HighConfidenceFactorThreshold", withValue: x); _analysisHighConfidenceFactorThreshold = x } }
	public static var analysisEnableLowConfidenceReports: Bool { get { return _analysisEnableLowConfidenceReports } set(x) { setBool("analysis.EnableLowConfidenceReports", withValue: x); _analysisEnableLowConfidenceReports = x } }
	public static var captureFrameWidth: Int { get { return _captureFrameWidth } set(x) { setInt("capture.FrameWidth", withValue: x); _captureFrameWidth = x } }
	public static var captureFrameHeight: Int { get { return _captureFrameHeight } set(x) { setInt("capture.FrameHeight", withValue: x); _captureFrameHeight = x } }
	public static var captureFrameRateHz: Int { get { return _captureFrameRateHz } set(x) { setInt("capture.FrameRateHz", withValue: x); _captureFrameRateHz = x } }
	public static var captureViewportFrequencyFrames: Int { get { return _captureViewportFrequencyFrames } set(x) { setInt("capture.ViewportFrequencyFrames", withValue: x); _captureViewportFrequencyFrames = x } }
	public static var captureViewportType: ViewportMessage.ViewportType { get { return _captureViewportType } set(x) { setInt("capture.ViewportType", withValue: Int(x.rawValue)); _captureViewportType = x } }
	public static var testbedDrawViewport: Bool { get { return _testbedDrawViewport } set(x) { setBool("testbed.DrawViewport", withValue: x); _testbedDrawViewport = x } }
	public static var testbedViewInterpolation: Bool { get { return _testbedViewInterpolation } set(x) { setBool("testbed.ViewInterpolation", withValue: x); _testbedViewInterpolation = x } }
	public static var testbedFilterInputHistogramNormalization: Bool { get { return _testbedFilterInputHistogramNormalization } set(x) { setBool("testbed.FilterInputHistogramNormalization", withValue: x); _testbedFilterInputHistogramNormalization = x } }
	public static var testbedFilterInputContrastEnhance: Bool { get { return _testbedFilterInputContrastEnhance } set(x) { setBool("testbed.FilterInputContrastEnhance", withValue: x); _testbedFilterInputContrastEnhance = x } }
	public static var testbedFilterInputHackMap: Bool { get { return _testbedFilterInputHackMap } set(x) { setBool("testbed.FilterInputHackMap", withValue: x); _testbedFilterInputHackMap = x } }
	public static var testbedFilterInputBoxFilter: Bool { get { return _testbedFilterInputBoxFilter } set(x) { setBool("testbed.FilterInputBoxFilter", withValue: x); _testbedFilterInputBoxFilter = x } }
	public static var testbedFilterInputLowPass: Bool { get { return _testbedFilterInputLowPass } set(x) { setBool("testbed.FilterInputLowPass", withValue: x); _testbedFilterInputLowPass = x } }
	public static var debugDrawSharpnessGraphs: Bool { get { return _debugDrawSharpnessGraphs } set(x) { setBool("debug.DrawSharpnessGraphs", withValue: x); _debugDrawSharpnessGraphs = x } }
	public static var debugDrawSearchedLines: Bool { get { return _debugDrawSearchedLines } set(x) { setBool("debug.DrawSearchedLines", withValue: x); _debugDrawSearchedLines = x } }
	public static var debugDrawMatchedDeckLocations: Bool { get { return _debugDrawMatchedDeckLocations } set(x) { setBool("debug.DrawMatchedDeckLocations", withValue: x); _debugDrawMatchedDeckLocations = x } }
	public static var debugDrawMatchedDeckLocationDiscards: Bool { get { return _debugDrawMatchedDeckLocationDiscards } set(x) { setBool("debug.DrawMatchedDeckLocationDiscards", withValue: x); _debugDrawMatchedDeckLocationDiscards = x } }
	public static var debugDrawMarkHistogram: Bool { get { return _debugDrawMarkHistogram } set(x) { setBool("debug.DrawMarkHistogram", withValue: x); _debugDrawMarkHistogram = x } }
	public static var debugDrawBitPatternHistogram: Bool { get { return _debugDrawBitPatternHistogram } set(x) { setBool("debug.DrawBitPatternHistogram", withValue: x); _debugDrawBitPatternHistogram = x } }
	public static var debugDrawDeckMatchResults: Bool { get { return _debugDrawDeckMatchResults } set(x) { setBool("debug.DrawDeckMatchResults", withValue: x); _debugDrawDeckMatchResults = x } }
	public static var debugDrawAllMarks: Bool { get { return _debugDrawAllMarks } set(x) { setBool("debug.DrawAllMarks", withValue: x); _debugDrawAllMarks = x } }
	public static var debugDrawMarkLines: Bool { get { return _debugDrawMarkLines } set(x) { setBool("debug.DrawMarkLines", withValue: x); _debugDrawMarkLines = x } }
	public static var debugDrawFullSearchGrid: Bool { get { return _debugDrawFullSearchGrid } set(x) { setBool("debug.DrawFullSearchGrid", withValue: x); _debugDrawFullSearchGrid = x } }
	public static var debugDrawSequentialSearchLineOrder: Bool { get { return _debugDrawSequentialSearchLineOrder } set(x) { setBool("debug.DrawSequentialSearchLineOrder", withValue: x); _debugDrawSequentialSearchLineOrder = x } }
	public static var debugDrawEdges: Bool { get { return _debugDrawEdges } set(x) { setBool("debug.DrawEdges", withValue: x); _debugDrawEdges = x } }
	public static var debugDrawSequencedEdgeDetection: Bool { get { return _debugDrawSequencedEdgeDetection } set(x) { setBool("debug.DrawSequencedEdgeDetection", withValue: x); _debugDrawSequencedEdgeDetection = x } }
	public static var debugDrawMouseEdgeDetection: Bool { get { return _debugDrawMouseEdgeDetection } set(x) { setBool("debug.DrawMouseEdgeDetection", withValue: x); _debugDrawMouseEdgeDetection = x } }
	public static var debugDrawDeckExtents: Bool { get { return _debugDrawDeckExtents } set(x) { setBool("debug.DrawDeckExtents", withValue: x); _debugDrawDeckExtents = x } }
	public static var debugDrawTraceMarks: Bool { get { return _debugDrawTraceMarks } set(x) { setBool("debug.DrawTraceMarks", withValue: x); _debugDrawTraceMarks = x } }
	public static var debugDrawScanResults: Bool { get { return _debugDrawScanResults } set(x) { setBool("debug.DrawScanResults", withValue: x); _debugDrawScanResults = x } }
	public static var debugBreakpointEnabled: Bool { get { return _debugBreakpointEnabled } set(x) { setBool("debug.BreakpointEnabled", withValue: x); _debugBreakpointEnabled = x } }
	public static var debugPauseOnIncorrectDecode: Bool { get { return _debugPauseOnIncorrectDecode } set(x) { setBool("debug.PauseOnIncorrectDecode", withValue: x); _debugPauseOnIncorrectDecode = x } }
	public static var debugPauseOnCorrectDecode: Bool { get { return _debugPauseOnCorrectDecode } set(x) { setBool("debug.PauseOnCorrectDecode", withValue: x); _debugPauseOnCorrectDecode = x } }
	public static var debugRotateFrame: Bool { get { return _debugRotateFrame } set(x) { setBool("debug.RotateFrame", withValue: x); _debugRotateFrame = x } }
	public static var debugValidateResults: Bool { get { return _debugValidateResults } set(x) { setBool("debug.ValidateResults", withValue: x); _debugValidateResults = x } }
	public static var debugViewportDebugView: Bool { get { return _debugViewportDebugView } set(x) { setBool("debug.ViewportDebugView", withValue: x); _debugViewportDebugView = x } }

	private static var _logFileLocations: [PathString] = [PathString]()
	private static var _logResetOnStart: Bool = false
	private static var _logMasks: [String: String] = [:]
	private static var _diagnosticLumaFilePath: PathString = PathString()
	private static var _systemReservedDiskSpaceMB: Int = 0
	private static var _edgeMinimumThreshold: RollValue = 0
	private static var _searchLineHorizontalWeightAdjustment: Real = 0
	private static var _searchLineRotationDensity: Real = 0
	private static var _searchLineRotationSteps: Real = 0
	private static var _searchLineMinAngleCutoff: Real = 0
	private static var _searchLineMaxAngleCutoff: Real = 0
	private static var _searchLineLinearLimitScalar: Real = 0
	private static var _searchLineLinearDensity: Real = 0
	private static var _searchLineLinearSteps: Real = 0
	private static var _searchLineBidirectional: Bool = false
	private static var _searchCodeDefinition: CodeDefinition?
	private static var _searchUseLandmarkContours: Bool = false
	private static var _searchMaxDeckMatchError: Real = 0
	private static var _searchEdgeDetectionDeckRollingMinMaxWindowMultiplier: Real = 0
	private static var _searchEdgeDetectionDeckPeakRollingAverageOverlap: Int = 0
	private static var _searchEdgeDetectionDeckEdgeSensitivity: FixedPoint = FixedPoint(0)
	private static var _searchTraceMarksEdgeSensitivity: FixedPoint = FixedPoint(0)
	private static var _searchTraceMarksMaxStray: FixedPoint = FixedPoint(0)
	private static var _searchTemporalExpirationMS: Time = 0
	private static var _searchBaseMaxEdgeTraceMisses: Int = 0
	private static var _searchTraceMarkBackupDistance: Int = 0
	private static var _searchBatterySaverStartMS: Int = 0
	private static var _searchBatterySaverIntervalMS: Int = 0
	private static var _decodeEnableSharpnessDetection: Bool = false
	private static var _decodeMinimumSharpnessUnitScalarThreshold: FixedPoint = FixedPoint(0)
	private static var _decodeResampleBitColumnLengthMultiplier: FixedPoint = FixedPoint(0)
	private static var _decodeMarkLineAverageOffsetMultiplier: FixedPoint = FixedPoint(0)
	private static var _resolveGenocideScaleFactor: FixedPoint = FixedPoint(0)
	private static var _deckMinSamplesPerCard: Real = 0
	private static var _analysisMissingCardPopularity: FixedPoint = FixedPoint(0)
	private static var _analysisMaxHistoryAgeMS: Int = 0
	private static var _analysisMinHistoryEntries: Int = 0
	private static var _analysisMinimumConfidenceFactorThreshold: Real = 0
	private static var _analysisHighConfidenceFactorThreshold: Real = 0
	private static var _analysisEnableLowConfidenceReports: Bool = false
	private static var _captureFrameWidth: Int = 0
	private static var _captureFrameHeight: Int = 0
	private static var _captureFrameRateHz: Int = 0
	private static var _captureViewportFrequencyFrames: Int = 0
	private static var _captureViewportType: ViewportMessage.ViewportType = .LumaResampledToViewportSize
	private static var _testbedDrawViewport: Bool = false
	private static var _testbedViewInterpolation: Bool = false
	private static var _testbedFilterInputHistogramNormalization: Bool = false
	private static var _testbedFilterInputContrastEnhance: Bool = false
	private static var _testbedFilterInputHackMap: Bool = false
	private static var _testbedFilterInputBoxFilter: Bool = false
	private static var _testbedFilterInputLowPass: Bool = false
	private static var _debugDrawSharpnessGraphs: Bool = false
	private static var _debugDrawSearchedLines: Bool = false
	private static var _debugDrawMatchedDeckLocations: Bool = false
	private static var _debugDrawMatchedDeckLocationDiscards: Bool = false
	private static var _debugDrawMarkHistogram: Bool = false
	private static var _debugDrawBitPatternHistogram: Bool = false
	private static var _debugDrawDeckMatchResults: Bool = false
	private static var _debugDrawAllMarks: Bool = false
	private static var _debugDrawMarkLines: Bool = false
	private static var _debugDrawFullSearchGrid: Bool = false
	private static var _debugDrawSequentialSearchLineOrder: Bool = false
	private static var _debugDrawEdges: Bool = false
	private static var _debugDrawSequencedEdgeDetection: Bool = false
	private static var _debugDrawMouseEdgeDetection: Bool = false
	private static var _debugDrawDeckExtents: Bool = false
	private static var _debugDrawTraceMarks: Bool = false
	private static var _debugDrawScanResults: Bool = false
	private static var _debugBreakpointEnabled: Bool = false
	private static var _debugPauseOnIncorrectDecode: Bool = false
	private static var _debugPauseOnCorrectDecode: Bool = false
	private static var _debugRotateFrame: Bool = false
	private static var _debugValidateResults: Bool = false
	private static var _debugViewportDebugView: Bool = false

	public static func cacheLoadedValues()
	{
		_logFileLocations = getPathArray("log.FileLocations")
		_logResetOnStart = getBool("log.ResetOnStart")
		_logMasks = getStringMap("log.Masks")
		_diagnosticLumaFilePath = getPath("diagnostic.LumaFilePath")
		_systemReservedDiskSpaceMB = getInt("system.ReservedDiskSpaceMB")
		_edgeMinimumThreshold = getRollValue("edge.MinimumThreshold")
		_searchLineHorizontalWeightAdjustment = getReal("search.LineHorizontalWeightAdjustment")
		_searchLineRotationDensity = getReal("search.LineRotationDensity")
		_searchLineRotationSteps = getReal("search.LineRotationSteps")
		_searchLineMinAngleCutoff = getReal("search.LineMinAngleCutoff")
		_searchLineMaxAngleCutoff = getReal("search.LineMaxAngleCutoff")
		_searchLineLinearLimitScalar = getReal("search.LineLinearLimitScalar")
		_searchLineLinearDensity = getReal("search.LineLinearDensity")
		_searchLineLinearSteps = getReal("search.LineLinearSteps")
		_searchLineBidirectional = getBool("search.LineBidirectional")
		_searchCodeDefinition = getCodeDefinition("search.CodeDefinition", fromCache: true)
		_searchUseLandmarkContours = getBool("search.UseLandmarkContours")
		_searchMaxDeckMatchError = getReal("search.MaxDeckMatchError")
		_searchEdgeDetectionDeckRollingMinMaxWindowMultiplier = getReal("search.EdgeDetectionDeckRollingMinMaxWindowMultiplier")
		_searchEdgeDetectionDeckPeakRollingAverageOverlap = getInt("search.EdgeDetectionDeckPeakRollingAverageOverlap")
		_searchEdgeDetectionDeckEdgeSensitivity = getFixed("search.EdgeDetectionDeckEdgeSensitivity")
		_searchTraceMarksEdgeSensitivity = getFixed("search.TraceMarksEdgeSensitivity")
		_searchTraceMarksMaxStray = getFixed("search.TraceMarksMaxStray")
		_searchTemporalExpirationMS = getTime("search.TemporalExpirationMS")
		_searchBaseMaxEdgeTraceMisses = getInt("search.BaseMaxEdgeTraceMisses")
		_searchTraceMarkBackupDistance = getInt("search.TraceMarkBackupDistance")
		_searchBatterySaverStartMS = getInt("search.BatterySaverStartMS")
		_searchBatterySaverIntervalMS = getInt("search.BatterySaverIntervalMS")
		_decodeEnableSharpnessDetection = getBool("decode.EnableSharpnessDetection")
		_decodeMinimumSharpnessUnitScalarThreshold = getFixed("decode.MinimumSharpnessUnitScalarThreshold")
		_decodeResampleBitColumnLengthMultiplier = getFixed("decode.ResampleBitColumnLengthMultiplier")
		_decodeMarkLineAverageOffsetMultiplier = getFixed("decode.MarkLineAverageOffsetMultiplier")
		_resolveGenocideScaleFactor = getFixed("resolve.GenocideScaleFactor")
		_deckMinSamplesPerCard = getReal("deck.MinSamplesPerCard")
		_analysisMissingCardPopularity = getFixed("analysis.MissingCardPopularity")
		_analysisMaxHistoryAgeMS = getInt("analysis.MaxHistoryAgeMS")
		_analysisMinHistoryEntries = getInt("analysis.MinHistoryEntries")
		_analysisMinimumConfidenceFactorThreshold = getReal("analysis.MinimumConfidenceFactorThreshold")
		_analysisHighConfidenceFactorThreshold = getReal("analysis.HighConfidenceFactorThreshold")
		_analysisEnableLowConfidenceReports = getBool("analysis.EnableLowConfidenceReports")
		_captureFrameWidth = getInt("capture.FrameWidth")
		_captureFrameHeight = getInt("capture.FrameHeight")
		_captureFrameRateHz = getInt("capture.FrameRateHz")
		_captureViewportFrequencyFrames = getInt("capture.ViewportFrequencyFrames")
		_captureViewportType = ViewportMessage.ViewportType.fromUInt8(UInt8(getInt("capture.ViewportType")))
		_testbedDrawViewport = getBool("testbed.DrawViewport")
		_testbedViewInterpolation = getBool("testbed.ViewInterpolation")
		_testbedFilterInputHistogramNormalization = getBool("testbed.FilterInputHistogramNormalization")
		_testbedFilterInputContrastEnhance = getBool("testbed.FilterInputContrastEnhance")
		_testbedFilterInputHackMap = getBool("testbed.FilterInputHackMap")
		_testbedFilterInputBoxFilter = getBool("testbed.FilterInputBoxFilter")
		_testbedFilterInputLowPass = getBool("testbed.FilterInputLowPass")
		_debugDrawSharpnessGraphs = getBool("debug.DrawSharpnessGraphs")
		_debugDrawSearchedLines = getBool("debug.DrawSearchedLines")
		_debugDrawMatchedDeckLocations = getBool("debug.DrawMatchedDeckLocations")
		_debugDrawMatchedDeckLocationDiscards = getBool("debug.DrawMatchedDeckLocationDiscards")
		_debugDrawMarkHistogram = getBool("debug.DrawMarkHistogram")
		_debugDrawBitPatternHistogram = getBool("debug.DrawBitPatternHistogram")
		_debugDrawDeckMatchResults = getBool("debug.DrawDeckMatchResults")
		_debugDrawAllMarks = getBool("debug.DrawAllMarks")
		_debugDrawMarkLines = getBool("debug.DrawMarkLines")
		_debugDrawFullSearchGrid = getBool("debug.DrawFullSearchGrid")
		_debugDrawSequentialSearchLineOrder = getBool("debug.DrawSequentialSearchLineOrder")
		_debugDrawEdges = getBool("debug.DrawEdges")
		_debugDrawSequencedEdgeDetection = getBool("debug.DrawSequencedEdgeDetection")
		_debugDrawMouseEdgeDetection = getBool("debug.DrawMouseEdgeDetection")
		_debugDrawDeckExtents = getBool("debug.DrawDeckExtents")
		_debugDrawTraceMarks = getBool("debug.DrawTraceMarks")
		_debugDrawScanResults = getBool("debug.DrawScanResults")
		_debugBreakpointEnabled = getBool("debug.BreakpointEnabled")
		_debugPauseOnIncorrectDecode = getBool("debug.PauseOnIncorrectDecode")
		_debugPauseOnCorrectDecode = getBool("debug.PauseOnCorrectDecode")
		_debugRotateFrame = getBool("debug.RotateFrame")
		_debugValidateResults = getBool("debug.ValidateResults")
		_debugViewportDebugView = getBool("debug.ViewportDebugView")
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	//      _ ____   ___  _   _
	//     | / ___| / _ \| \ | |
	//  _  | \___ \| | | |  \| |
	// | |_| |___) | |_| | |\  |
	//  \___/|____/ \___/|_| \_|
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Performs an entry-by-entry JSON conversion of the input `dict` in key-sorted order
	public static func toSortedJSON(skipPublic: Bool = false) -> String?
	{
		// Can we serialize the dictionary?
		if !JSONSerialization.isValidJSONObject(configDict)
		{
			gLogger.error("Invalid JSON object: (Config.configDict) cannot be serialized")
			return nil
		}

		// Try to serialize each key in sorted order
		var jsonString = ""
		for key in configDict.keys.sorted()
		{
			guard let valueDict = configDict[key] else { continue }

			let entryDict = [key: valueDict]

			do
			{
				let entry = try JSONSerialization.data(withJSONObject: entryDict, options: [.prettyPrinted])

				if var entryString = String(data: entry)
				{
					if !jsonString.isEmpty
					{
						jsonString += ",\n"
					}
					entryString = entryString.trim("{}")
					entryString = entryString.trim()
					jsonString += "  \(entryString)"
				}
			}
			catch
			{
				gLogger.warn("Invalid JSON object: (Config.configDict) cannot serialize key: '\(key)'")
			}
		}

		return "{\n\(jsonString)\n}"
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	//  _   _      _                      _       __  __
	// | \ | | ___| |___      _____  _ __| | __  |  \/  | ___  ___ ___  __ _  __ _  ___  ___
	// |  \| |/ _ \ __\ \ /\ / / _ \| '__| |/ /  | |\/| |/ _ \/ __/ __|/ _` |/ _` |/ _ \/ __|
	// | |\  |  __/ |_ \ V  V / (_) | |  |   <   | |  | |  __/\__ \__ \ (_| | (_| |  __/\__ \
	// |_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\  |_|  |_|\___||___/___/\__,_|\__, |\___||___/
	//                                                                       |___/
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	private static func doubleFrom(anyValue: Any?) -> Double?
	{
		if let dResult = anyValue as? Double { return dResult }
		if let iResult = anyValue as? Int { return Double(iResult) }
		return nil
	}

	/// Returns a ConfigValueMessage for the value of the given `name`
	///
	/// If `name` does not represent a valid value, then this method will return `nil`
	public static func getConfigValueMessage(name: String) -> ConfigValueMessage?
	{
		guard let valueDict = configDict[name] else { return nil }
		guard let strType = valueDict["type"] as? String else { return nil }
		guard let type = ValueType(rawValue: strType) else { return nil }

		switch type
		{
			case .String:
				guard let value = valueDict["value"] as? String else { return nil }
				return ConfigValueMessage(name: name, withString: value)
			case .Path:
				guard let value = valueDict["value"] as? PathString else { return nil }
				return ConfigValueMessage(name: name, withPath: value)
			case .PathArray:
				guard let value = valueDict["value"] as? [PathString] else { return nil }
				return ConfigValueMessage(name: name, withPathArray: value)
			case .CodeDefinition:
				guard let cdName = valueDict["value"] as? String else { return nil }
				guard let value = CodeDefinition.findCodeDefinition(byName: cdName) else { return nil }
				return ConfigValueMessage(name: name, withCodeDefinition: value)
			case .StringMap:
				guard let value = valueDict["value"] as? [String: String] else { return nil }
				return ConfigValueMessage(name: name, withStringMap: value)
			case .Boolean:
				guard let value = valueDict["value"] as? Bool else { return nil }
				return ConfigValueMessage(name: name, withBoolean: value)
			case .Integer:
				guard let value = valueDict["value"] as? Int else { return nil }
				return ConfigValueMessage(name: name, withInteger: value)
			case .FixedPoint:
				guard let value = doubleFrom(anyValue: valueDict["value"]) else { return nil }
				return ConfigValueMessage(name: name, withFixedPoint: FixedPoint(value))
			case .Real:
				guard let value = doubleFrom(anyValue: valueDict["value"]) else { return nil }
				return ConfigValueMessage(name: name, withReal: Real(value))
			case .RollValue:
				guard let value = doubleFrom(anyValue: valueDict["value"]) else { return nil }
				return ConfigValueMessage(name: name, withRollValue: RollValue(value))
			case .Time:
				guard let value = doubleFrom(anyValue: valueDict["value"]) else { return nil }
				return ConfigValueMessage(name: name, withTime: Time(value))
		}
	}

	/// Set the config value to one matching the given name specified in the message
	public static func onConfigValue(message: ConfigValueMessage)
	{
		switch message.valueType
		{
			case .String:
				if let value = message.stringValue
				{
					Config.setString(message.name, withValue: value)
				}
				else
				{
					gLogger.error("Config.onConfigValue: Failed to set String value for name '\(message.name)' - value was nil")
				}
			case .Path:
				if let value = message.pathValue
				{
					Config.setPath(message.name, withValue: value)
				}
				else
				{
					gLogger.error("Config.onConfigValue: Failed to set Path value for name '\(message.name)' - value was nil")
				}
			case .PathArray:
				if let pathArray = message.pathArrayValue
				{
					Config.setPathArray(message.name, withValue: pathArray)
				}
				else
				{
					gLogger.error("Config.onConfigValue: Failed to set PathArray value for name '\(message.name)' - value was nil")
				}
			case .CodeDefinition:
				if let codeDefinition = message.codeDefinitionValue
				{
					Config.searchCodeDefinition = codeDefinition
				}
				else
				{
					gLogger.error("Config.onConfigValue: Failed to set CodeDefinition value for name '\(message.name)' - value was nil")
				}
			case .StringMap:
				if let value = message.stringMapValue
				{
					Config.setStringMap(message.name, withValue: value)
				}
				else
				{
					gLogger.error("Config.onConfigValue: Failed to set StringMap value for name '\(message.name)' - value was nil")
				}
			case .Boolean:
				if let value = message.booleanValue
				{
					Config.setBool(message.name, withValue: value)
				}
				else
				{
					gLogger.error("Config.onConfigValue: Failed to set Boolean value for name '\(message.name)' - value was nil")
				}
			case .Integer:
				if let value = message.integerValue
				{
					Config.setInt(message.name, withValue: value)
				}
				else
				{
					gLogger.error("Config.onConfigValue: Failed to set Integer value for name '\(message.name)' - value was nil")
				}
			case .FixedPoint:
				if let value = message.fixedPointValue
				{
					Config.setFixed(message.name, withValue: value)
				}
				else
				{
					gLogger.error("Config.onConfigValue: Failed to set FixedPoint value for name '\(message.name)' - value was nil")
				}
			case .Real:
				if let value = message.realValue
				{
					Config.setReal(message.name, withValue: value)
				}
				else
				{
					gLogger.error("Config.onConfigValue: Failed to set Real value for name '\(message.name)' - value was nil")
				}
			case .RollValue:
				if let value = message.rollValue
				{
					Config.setRollValue(message.name, withValue: value)
				}
				else
				{
					gLogger.error("Config.onConfigValue: Failed to set RollValue value for name '\(message.name)' - value was nil")
				}
			case .Time:
				if let value = message.timeValue
				{
					Config.setTime(message.name, withValue: value)
				}
				else
				{
					gLogger.error("Config.onConfigValue: Failed to set Time value for name '\(message.name)' - value was nil")
				}
		}

		Config.cacheLoadedValues()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	//  _   _       _   _  __ _           _   _
	// | \ | | ___ | |_(_)/ _(_) ___ __ _| |_(_) ___  _ __  ___
	// |  \| |/ _ \| __| | |_| |/ __/ _` | __| |/ _ \| '_ \/ __|
	// | |\  | (_) | |_| |  _| | (_| (_| | |_| | (_) | | | \__ \
	// |_| \_|\___/ \__|_|_| |_|\___\__,_|\__|_|\___/|_| |_|___/
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Add a notification receiver
	///
	/// Returns the ID of the receiver, which can be used to remove it via `removeValueChangeNotificationReceiver`.
	public static func addValueChangeNotificationReceiver(receiver: @escaping ValueChangedNoticationReceiver) -> Int
	{
		let notification = ValueChangedNotication(receiver: receiver)
		valueChangedNotifications.append(notification)
		return notification.id
	}

	/// Remove a notification receiver
	///
	/// The `id` should have been returned by `addValueChangeNotificationReceiver`.
	///
	/// Returns true if the `id` is valid and the reciever is removed, otherwise false
	public static func removeValueChangeNotificationReceiver(id: Int) -> Bool
	{
		guard let idx = valueChangedNotifications.firstIndex(where: {$0.id == id}) else { return false }
		valueChangedNotifications.remove(at: idx)
		return true
	}

	/// Sends a notification to all receivers that the value for `name` has changed.
	///
	/// If `name` is omitted (or set to `nil`) then it is assumed that the full configuration has been loaded or changed.
	public static func notify(_ name: String? = nil)
	{
		for notification in valueChangedNotifications
		{
			notification.receiver(name)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	//  _____ _ _         ___    _____
	// |  ___(_) | ___   |_ _|  / / _ \
	// | |_  | | |/ _ \   | |  / / | | |
	// |  _| | | |  __/   | | / /| |_| |
	// |_|   |_|_|\___|  |___/_/  \___/
	//
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initializes a `Config` object and load a configuration
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
	public static func loadConfiguration(configBaseName: String)
	{
		var success = false

		configFilename = configBaseName
		if let filename = configFilename
		{
			var configFilePaths = [PathString]()

			if Bundle.main.resourcePath != nil
			{
				configFilePaths.append(PathString(Bundle.main.resourcePath!) + filename)
			}

			configFilePaths.append(PathString("/etc") + filename)
			configFilePaths.append(PathString("/usr/local/etc") + filename)
			configFilePaths.append(PathString("~/") + ".\(filename)")

			// Load our config files, in the order they appear on our paths
			for path in configFilePaths
			{
				if apply(fromFile: path.toAbsolutePath())
				{
					success = true
				}
			}
		}

		// Cache our config values
		Config.cacheLoadedValues()

		// Notify the world that we've changed
		notify()

		if !success
		{
			gLogger.warn("Unable to load any configuration files")
		}
	}

	/// Apply any configuration values found in the file `filePath` to the configuration values
	///
	/// `filePath` must point to a file containing a single JSON object with fields that coordinate with configuration values
	/// stored in this class.
	///
	/// If the file is loaded and parsed successfully, a ConfigDict representation of that file is returned, otherwise `nil` is
	/// returned. Note that this doesn't mean that any part of the Config object was updated as the resulting ConfigDict may
	/// be empty or may contain values that do not map to values stored in this Config object.
	private static func apply(fromFile filePath: PathString) -> Bool
	{
		do
		{
			// Is the file actually a directory?
			if filePath.isDirectory()
			{
				throw "Config file specifies directory: \(filePath)"
			}

			// Ensure it's a file that exists
			if !filePath.isFile()
			{
				return false
			}

			gLogger.info("Loading config file from \(filePath)")

			// Try to load the file
			guard let configData = try? Data(contentsOf: filePath.toUrl(), options: .uncached) else
			{
				throw "Unable to load config file: \(filePath)"
			}

			// Try to deserialize it
			do
			{
				let json = try JSONSerialization.jsonObject(with: configData, options: [])

				// Convert to a dictionary
				if let loadedDict = json as? ConfigDict
				{
					// Apply the loaded dict by adding/replacing any values from the loadedDict
					for key in loadedDict.keys
					{
						if let loadedSubdict = loadedDict[key] as? [String: Any]
						{
							if Config.configDict[key] == nil
							{
								Config.configDict[key] = loadedSubdict
							}
							else
							{
								if let loadedValue = loadedSubdict["value"]
								{
									Config.configDict[key]?["value"] = loadedValue
								}
							}
						}
						else
						{
							gLogger.warn("Unable to load subdict for key \(key)")
						}
					}
					return true
				}
			}
			catch
			{
				throw "Unable to deserialize config file: \(filePath): \(error.localizedDescription)"
			}

			throw "Failed to extract configuration data, likely from non object-root type config file: \(filePath)"
		}
		catch
		{
			// We don't log errors since these errors may be normal - also, we haven't fully configured the logging.
			gLogger.error(error.localizedDescription)
		}

		return false
	}

	/// Stores the configuration file to the file specified by `filename`.
	///
	/// If `filename` is nil then tiered loading order is inverted and the first successful write is used. The file will be stored
	/// using the same base filename (`configFilename`) from which it was most recently loaded (via `loadConfiguration()`)
	///
	/// If `filename` cannot be written and the tiered storage fails, the method returns `false`. Otherwise `true` is returned.
	public static func write(to filename: String? = nil) -> Bool
	{
		// Serialize our configDict in key-sorted order
		guard let jsonData = toSortedJSON()?.data else
		{
			gLogger.warn("Failed to serialize configDict")
			return false
		}

		var configFilePaths = [PathString]()

		if let filename = filename
		{
			configFilePaths.append(PathString(filename))
		}
		else if let filename = configFilename
		{
			configFilePaths.append(PathString("~/") + ".\(filename)")
			configFilePaths.append(PathString("/usr/local/etc") + filename)
			configFilePaths.append(PathString("/etc") + filename)
		}
		else
		{
			gLogger.error("No filename for configuration serialization")
			return false
		}

		// Write our config files, in the order they appear on our paths
		for path in configFilePaths
		{
			let filePath = path.toAbsolutePath()
			do
			{
				// Try to write the file
				let tempConfigFileUrl = (filePath * kTempExtension).toUrl()
				try jsonData.write(to: tempConfigFileUrl)

				let configFileUrl = filePath.toUrl()
				do
				{
					try? FileManager.default.removeItem(at: configFileUrl)
					try FileManager.default.moveItem(at: tempConfigFileUrl, to: configFileUrl)

					gLogger.info("Config file written to \(configFileUrl)")
					return true
				}
				catch
				{
					gLogger.error("Config file written to \(tempConfigFileUrl) could not be moved to \(configFileUrl): \(error.localizedDescription)")
					try? FileManager.default.removeItem(at: tempConfigFileUrl)
				}
			}
			catch
			{
				// We don't log errors since these errors may be normal - we're trying a few different locations
			}
		}

		return false
	}
}
