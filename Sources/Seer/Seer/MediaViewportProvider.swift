//
//  MediaViewportProvider.swift
//  Seer
//
//  Created by Paul Nettle on 04/18/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

/// The Media Viewport Provider is responsible for displaying the the `DebugBuffer` view of the scanning and decoding process. This
/// includes the display of a block of scanning statistics (a `ResultStats` instance).
public protocol MediaViewportProvider
{
	/// Displays the debug buffer image
	///
	/// Implementors should copy the image buffer and not rely on its memory beyond the extend of this call. In addition, it should
	/// check for changes in the image's dimensions (as the media may have changed since the last call) and react accordingly.
	func updateLocalViewport(debugBuffer: DebugBuffer?)

	/// Receives a `ResultsStats` display updates to the user
	func updateStats(analysisResult: AnalysisResult, stats: ResultStats)

	/// Provides a mechanism for saving the `DebugBuffer` as a color image (such as PNG or JPG.)
	///
	/// This method is similar to `MediaProvider.archiveFrame()` except that this method stores the debug buffer, which may have
	/// color debug information drawn within that can be useful for, well, debugging.
	func writeViewport()
}
