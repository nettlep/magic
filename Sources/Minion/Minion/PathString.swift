//
//  PathString.swift
//  Minion
//
//  Created by Paul Nettle on 3/22/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// Path-based operations
public struct PathString
{
	/// The underlying path string
	private var pathString: String

	/// The path separator used in pathing functions
	///
	/// Note that this is OS-dependent and as such, only supported OSs are listed causing an error for those OSs that are not
	/// currently supported.
	private static let kPathSeparator: String = "/"

	/// The home directory token
	///
	/// Note that this is OS-dependent and as such, only supported OSs are listed causing an error for those OSs that are not
	/// currently supported.
	private static let kPathHomeToken: String = "~/"

	/// Returns a URL form of the path
	public func toUrl() -> URL
	{
		return URL(fileURLWithPath: pathString)
	}

	/// Returns a String form of the path
	public func toString() -> String
	{
		return pathString
	}

	/// Returns a Path containing all lowercased characters
	public func lowercased() -> PathString
	{
		return PathString(pathString.lowercased())
	}

	/// Returns `true` if the path ends with `suffix`, otherwise `false`
	public func hasSuffix(_ suffix: String) -> Bool
	{
		return pathString.hasSuffix(suffix)
	}

	/// Returns `true` if the path begins with `prefix`, otherwise `prefix`
	public func hasPrefix(_ prefix: String) -> Bool
	{
		return pathString.hasPrefix(prefix)
	}

	/// Returns `true` if the path is empty, otherwise `false`
	public var isEmpty: Bool { return pathString.isEmpty }

	/// Initialize with an empty path
	public init()
	{
		self.pathString = ""
	}

	/// Initialize with a string
	public init(_ pathString: String)
	{
		self.pathString = pathString
	}

	/// Initialize with a string
	public init?(_ pathString: String?)
	{
		if pathString == nil { return nil }
		self.pathString = pathString!
	}

	/// Returns a new path with `right` concatenated onto `left` (path-aware)
	///
	/// This is a path-aware concatenation and includes path separators where necessary. For details, see `operator +=`.
	///
	/// For a raw (non-path-aware concatentation without path separators, see `operator *`.
	public static func + (left: PathString, right: String) -> PathString
	{
		var result = left
		result += right
		return result
	}

	/// Concatenates `right` onto `left` in-place (path-aware)
	///
	/// This is a path-aware concatenation and includes path separators where necessary. For a raw (non-path-aware concatentation
	/// without path separators, see `operator *=`.
	///
	/// Implementation notes:
	///
	///		* The path separator used is defined in `kPathSeparator`
	///
	/// Examples:
	///
	///		String Value			`Component` Parameter		Resulting String
	///		“~”						"foo.txt"					“~/foo.txt”
	///		“~/”					"foo.txt"					“~/foo.txt”
	///		“.”						"foo.txt"					“./foo.txt”
	///		“./”					"foo.txt"					“./foo.txt”
	///		“/foo”					"bar"						“/foo/bar”
	///		“/foo/”					"bar.txt"					“/foo/bar.txt”
	///		“/foo/”					"/bar.txt"					“/foo/bar.txt”
	///		“/foo/”					"~/bar.txt"					“/foo/~/bar.txt”
	///		“/”						"baz.bin"					“/baz.bin”
	///		“” (an empty string)	"readme.txt"				“readme.txt”
	public static func += (left: inout PathString, right: String)
	{
		// `left` always takes the identity of `right` if `left` is empty
		if left.isEmpty
		{
			left.pathString = right
			return
		}

		let leftSeparator = left.pathString.hasSuffix(PathString.kPathSeparator)
		let rightSeparator = right.hasPrefix(PathString.kPathSeparator)

		// Both have a path separator; remove one and concatenate
		if leftSeparator && rightSeparator
		{
			left.pathString += right.firstRemoved()
		}

		// Only one has a path separator; simple concatenation
		else if leftSeparator || rightSeparator
		{
			left.pathString += right
		}

		// Neither have a separator; concatenate with a separator between them
		else
		{
			left.pathString += PathString.kPathSeparator + right
		}

		return
	}

	/// Returns a new path with `right` concatenated onto `left` (non-path-aware)
	///
	/// This is a non-path-aware concatenation and does not include path separators. This is useful for adding file extensions to
	/// filenames, for example. For a path-aware concatenation with path separators, see `operator +`
	public static func * (left: PathString, right: String) -> PathString
	{
		var result = left
		result *= right
		return result
	}

	/// Concatenates `right` onto `left` in-place (non-path-aware)
	///
	/// This is a non-path-aware concatenation and does not include path separators. This is useful for adding file extensions to
	/// filenames, for example. For a path-aware concatenation with path separators, see `operator +=`
	public static func *= (left: inout PathString, right: String)
	{
		left.pathString += right
	}

	/// Returns the user's existing home directory as a path or nil if it cannot be located or does not exist
	public static func homeDirectory() -> PathString?
	{
		//#if os(Linux)
		if let homeDir = ProcessInfo.processInfo.environment["HOME"]
		{
			return PathString(homeDir)
		}
		else
		{
			return nil
		}
		//#else
		//let dir = FileManager.default.homeDirectoryForCurrentUser.path
		//return dir.isDirectory() ? PathString(dir) : nil
		//#endif
	}

	/// Returns the current directory as a path or nil if it cannot be located or does not exist
	///
	/// If the current directory doesn't resolve as a valid directory for some reason, this method will fall back to a standard
	/// "./" path. This behavior can be disabled by setting `withFallback` to false.
	public static func currentDirectory(withFallback fallback: Bool = true) -> PathString?
	{
		let dir = PathString(FileManager.default.currentDirectoryPath)
		return dir.isDirectory() ? dir : (fallback ? PathString(".\(PathString.kPathSeparator)") : nil)
	}

	/// Returns a path to the subdirectory of self as a path or nil if it cannot be located or does not exist
	public func getSubdir(_ subdir: String) -> PathString?
	{
		let dir = self + subdir
		return dir.isDirectory() ? dir : nil
	}

	/// Returns an array of filenames (optionally matching `pattern`) found in the directory.
	///
	/// Filenames are strings as they do not include the path of this object
	///
	/// If the directory does not exist or is empty, an empty array is returned
	public func contentsOfDirectory(pattern: String? = nil) -> [String]
	{
		var filenames = [String]()

		// Get the files (as strings)
		if var strFiles = (try? FileManager.default.contentsOfDirectory(atPath: pathString))
		{
			// If we have a pattern and some files, filter by the pattern
			if pattern != nil && !strFiles.isEmpty
			{
				guard let regex = try? NSRegularExpression(pattern: pattern!, options: []) else { return filenames }
				strFiles = strFiles.filter { regex.firstMatch(in: $0, options: [], range: NSRange(location: 0, length: $0.length())) != nil }
			}

			// Convert to paths
			for file in strFiles
			{
				filenames.append(file)
			}
		}

		return filenames
	}

	/// Returns the largest numbered entry from the files (optionally matching `pattern`) from a directory.
	///
	/// A numbered file is one that starts with at least one digit character. The digits are extracted and converted to an integer,
	/// with the largest integer from the set of files being returned. If no matching numbered files are found, this method will
	/// return nil.
	public func getLargestFileNumberFromDirectory(pattern: String?) -> Int?
	{
		// Get the files to scan
		let filenames = contentsOfDirectory(pattern: pattern)
		if filenames.isEmpty { return nil }

		guard let regex = try? NSRegularExpression(pattern: "^[0-9]+", options: []) else { return nil }

		var maxFileNumber: Int?
		for filename in filenames
		{
			guard let match = regex.firstMatch(in: filename, options: [], range: NSRange(location: 0, length: filename.length())) else { continue }

			let mr = match.range
			let start = filename.index(filename.startIndex, offsetBy: mr.location)
			let end = filename.index(filename.startIndex, offsetBy: mr.location + mr.length)
			let digits = String(filename[start..<end])
			if let val = Int(digits, radix: 10)
			{
				if maxFileNumber == nil || maxFileNumber! < val
				{
					maxFileNumber = val
				}
			}
		}

		return maxFileNumber
	}

	/// Returns the available disk space for the device at the path specified by this string
	public func availableSpaceForPath() -> UInt64?
	{
		// The method needed (`attributesOfFileSystem(forPath:)`) isn't implemented (yet) in the Linux version of the Swift
		// Foundation core code.
		//
		// On Linux, this error was produced:
		//
		// fatal error: attributesOfFileSystem(forPath:) is not yet implemented: file Foundation/NSFileManager.swift, line 339
		//
		// As of 9/6/2017, there is a PR for an implementation, but it has yet to be accepted:
		//
		// https://github.com/apple/swift-corelibs-foundation/pull/888/files/f826e7b51f2ed24a97eb92d6180bdcbac42c2653?diff=unified)

		#if os(Linux)
			var stats = statvfs()
			if statvfs(pathString, &stats) != 0 { return nil }
			return UInt64(stats.f_bsize) * UInt64(stats.f_bavail)
		#else
			let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: pathString)
			let freeSize = systemAttributes?[FileAttributeKey.systemFreeSize] as? NSNumber
			return freeSize?.uint64Value
		#endif
	}

	/// Returns a new string by converting the current String to an absolute path
	///
	/// This method includes home-directory expansion.
	public func toAbsolutePath() -> PathString
	{
		// If we are already absolute, just return self
		if pathString.hasPrefix(PathString.kPathSeparator)
		{
			return self
		}

		let fileManager = FileManager.default

		// Is this path relative to the home directory?
		if pathString.hasPrefix(PathString.kPathHomeToken)
		{
			if let homeDir = PathString.homeDirectory()
			{
				let homeDirRelativePath = String(pathString[PathString.kPathHomeToken.endIndex...])
				let result = homeDir + homeDirRelativePath
				return result
			}
		}

		// Assume it's relative, append the current directory to the start
		return PathString(fileManager.currentDirectoryPath) + pathString
	}

	/// Returns a path with the last path component removed, or nil if the operation would result in an empty path
	///
	/// NOTES:
	///
	///		* Trailing path separators are ignored, which means that if a path ends with a path separator, then the returned string
	///		  be the part of the path immediately preceding the trailing path separator.
	///		* This is strictly string manipulation and does not perform any path validation
	///		* The path will remain at its initial scope (either relative or absolute.) To make the path absolute and resolve any
	///		  expansion, see `toAbsolutePath()`
	///		* The path will not end with a terminating path separator. This means that if the input path is a file in
	///		  the root directory ("/foo.txt"), then the result will be an empty path.
	///
	/// This method returns nil if
	public func withoutLastComponent() -> PathString?
	{
		let sanitized = pathString.trimTrailing(PathString.kPathSeparator)
		var parts = sanitized.split(on: PathString.kPathSeparator)
		if parts.isEmpty || parts.count < 2 { return nil }
		parts.removeLast(1)
		return PathString(parts.joined(separator: PathString.kPathSeparator))
	}

	/// Returns the last path component
	///
	/// Trailing path separators are ignored
	///
	/// NOTE: The returned path component will not begin with or with a terminating path separator
	public func lastComponent() -> String?
	{
		if isEmpty { return nil }
		let sanitized = pathString.trimTrailing(PathString.kPathSeparator)
		return sanitized.split(on: PathString.kPathSeparator).last ?? pathString
	}

	/// Creates the directory specified by the current String path
	///
	/// The path is first converted to an absolute path via `toAbsolutePath()`
	///
	/// This method will create the intermediate directories by default. To disable this behavior, set `withIntermediates` to
	/// false.
	///
	/// Returns true if the directory exists (i.e., was either created successfully or already existed), false otherwise
	public func createDirectory(withIntermediateDirectories: Bool = true) -> Bool
	{
		let path = toAbsolutePath()
		do
		{
			try FileManager.default.createDirectory(atPath: path.pathString, withIntermediateDirectories: withIntermediateDirectories, attributes: nil)
			return path.isDirectory()
		}
		catch
		{
			// We'll leave it up to the caller to decide if this is a problem
			// gLogger.error("Unable to create directory at path ('\(path)', intermediates = \(intermediates)): \(error.localizedDescription)")
		}

		return false
	}

	/// Creates the file specified by the current String path
	///
	/// The path is first converted to an absolute path via `toAbsolutePath()`
	///
	/// This method will not create any directories at the path.
	///
	/// If the file exists, it is truncated.
	///
	/// Returns true if the path specifies a file that exists (i.e., was either created or truncated successfully), false otherwise
	public func createFile() -> Bool
	{
		let path = toAbsolutePath()
		if path.isDirectory() { return false }

		// Create the file, and double-check that it is a file that actually exists
		return FileManager.default.createFile(atPath: path.pathString, contents: nil) && path.isFile()
	}

	/// Returns true if the string represents a path to an existing directory (not a file)
	public func isDirectory() -> Bool
	{
		var isDirectory: ObjCBool = false
		let exists = FileManager.default.fileExists(atPath: pathString, isDirectory: &isDirectory)
		return exists && isDirectory.boolValue
	}

	/// Returns true if the string represents a path to an existing file (not a directory)
	public func isFile() -> Bool
	{
		var isDirectory: ObjCBool = false
		let exists = FileManager.default.fileExists(atPath: pathString, isDirectory: &isDirectory)
		return exists && !isDirectory.boolValue
	}

	/// Appends the string followed by a to a file at this path
	public func appendToFile(text: String) throws
	{
		let data = text.data(using: String.Encoding.utf8)!
		try appendToFile(data: data)
	}

	/// Appends the string followed by a to a file at this path
	public func appendToFile(data: Data) throws
	{
		try data.appendToFile(fileUrl: toUrl())
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Equatable
// ---------------------------------------------------------------------------------------------------------------------------------

extension PathString: Equatable
{
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension PathString: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		return toString()
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Codable
// ---------------------------------------------------------------------------------------------------------------------------------

extension PathString: Codable
{
	/// Encodable conformance
	public func encode(into data: inout Data) -> Bool
	{
		if !toString().encode(into: &data) { return false }
		return true
	}

	/// Decodable conformance
	public static func decode(from data: Data, consumed: inout Int) -> PathString?
	{
		guard let pathString = String.decode(from: data, consumed: &consumed) else { return nil }
		return PathString(pathString)
	}
}
