//
//  NSImage.swift
//  Minion
//
//  Created by Paul Nettle on 3/20/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#if os(macOS)

import Foundation
import AppKit

public extension NSImage
{
	var png: Data?
	{
		return tiffRepresentation?.bitmap?.png
	}

	/// Saves an NSImage as a PNG file to `url`
	///
	/// Returns error string on error, otherwise nil
	///
	/// Throws:
	///		* An error in the Cocoa domain, if there is an error writing to the `URL`.
	///		* An ImageError.ConversionError if a PNG representation cannot be created
	func savePng(to url: URL) throws
	{
		if let png = self.png
		{
			try png.write(to: url)
		}
		else
		{
			throw ImageError.Conversion("Unable to create PNG representation of image for writing to URL: \(url)")
		}
	}
}

#endif
