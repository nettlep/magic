//
//  RenderView.swift
//  Originally from: Color Studio (with modifications)
//
//  Created by Paul Nettle on 3/24/14.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

// This file only applies to macOS and iOS
#if os(macOS) || os(iOS)

import Foundation
#if os(macOS)
import Cocoa
import Minion
#elseif os(iOS)
import UIKit
import MinionIOS
#endif

/// Typealias for the platform-dependent base view class
#if os(macOS)
public typealias RenderViewBase = NSView
#elseif os(iOS)
public typealias RenderViewBase = UIView
#endif

/// RenderView is a View-based class that manages its own frame buffer that can be rendered to a View
///
/// The type is designable (via `@IBDesignable`)
@IBDesignable
open class RenderView: RenderViewBase
{
	#if os(macOS)
	public typealias UIRect = NSRect
	#elseif os(iOS)
	public typealias UIRect = CGRect
	#endif

	// -----------------------------------------------------------------------------------------------------------------------------
	// Locals constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Dimensions of the default image (used for width & height)
	static let kDefaultDimension = 64

	// -----------------------------------------------------------------------------------------------------------------------------
	// Locals properties
	// -----------------------------------------------------------------------------------------------------------------------------

	private var frameBuffer: ImageBuffer<Color>?

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	public required init?(coder: NSCoder)
	{
		super.init(coder: coder)
		initDefaultImage()
	}

	public override init(frame framerect: UIRect)
	{
		super.init(frame: framerect)
		initDefaultImage()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Drawing & presentation
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Custom RenderView handling of the draw method for the underlying view
	///
	/// This method is aware of the `Config` setting `testbedDrawViewport` and will draw a blank view if this config value is
	/// set to `false`
	///
	/// In addition, on macOS, the viewport is drawn with high-quality interpolation based on the value of
	/// `Config.testbedViewInterpolation`.
	open override func draw(_ rect: UIRect)
	{
		super.draw(rect)

		if Config.testbedDrawViewport
		{
			#if os(macOS)
			drawBuffer(lowQuality: !Config.testbedViewInterpolation)
			#elseif os(iOS)
			drawBuffer()
			#endif
		}
		else
		{
			if let context = getContext()
			{
				context.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
				context.fill(bounds)
			}
		}
	}

	/// Draw the current `frameBuffer` bounds of the view using the given interpolation quality.
	///
	/// If the dimensions of `buffer` are not equal to view's bounds then the image will be interpolated. The quality of this
	/// interpolation is default quality unless `lowQuality` is set to true. Interpolation ignores aspect ratio.
	#if os(macOS)
	public func drawBuffer(lowQuality: Bool = false)
	{
		if let frameBuffer = frameBuffer
		{
			drawBuffer(frameBuffer, targetRect: bounds, lowQuality: lowQuality)
		}
	}
	#elseif os(iOS)
	public func drawBuffer()
	{
		if let frameBuffer = frameBuffer
		{
			drawBuffer(frameBuffer, targetRect: bounds)
		}
	}
	#endif

	/// Draw the given `ColorBuffer` to the given target rect using the given interpolation quality.
	///
	/// If `targetRect` is `nil` then the view's `bounds` is used.
	///
	/// If the dimensions of `buffer` are not equal to target rectangle (either `targetRect` or `bounds`) then the image will be
	/// interpolated. The quality of this interpolation is default quality unless `lowQuality` is set to true. Interpolation
	/// ignores aspect ratio.
	#if os(macOS)
	public func drawBuffer(_ buffer: ImageBuffer<Color>, targetRect: UIRect?, lowQuality: Bool = false)
	{
		// Setup our context
		guard let context = getContext() else
		{
			gLogger.error("Unable to get Graphics context for drawBuffer")
			return
		}

		guard let image = buffer.buffer.toCGImage(width: buffer.width, height: buffer.height) else
		{
			gLogger.error("Unable to get CGImage from raw pixel buffer")
			return
		}

		context.interpolationQuality = lowQuality ? CGInterpolationQuality.none : CGInterpolationQuality.default
		context.draw(image, in: targetRect ?? bounds)
	}
	#elseif os(iOS)
	public func drawBuffer(_ buffer: ImageBuffer<Color>, targetRect: UIRect?)
	{
		// Setup our context
		guard let context = getContext() else
		{
			gLogger.error("Unable to get Graphics context for drawBuffer")
			return
		}

		guard let image = buffer.buffer.toCGImage(width: buffer.width, height: buffer.height) else
		{
			gLogger.error("Unable to get CGImage from raw pixel buffer")
			return
		}

		context.saveGState()
		defer { context.restoreGState() }

		context.translateBy(x: frame.width / 2, y: frame.height / 2)
		context.scaleBy(x: frame.width/frame.height, y: frame.height/frame.width)
		context.scaleBy(x: -1, y: 1)
		context.rotate(by: CGFloat.pi / 2)
		context.translateBy(x: -frame.width / 2, y: -frame.height / 2)

		context.draw(image, in: targetRect ?? bounds)
	}
	#endif

	/// Request that the view be redrawn
	///
	/// Redrawing does not happen instantely, but on the next round of UI updates
	public func present()
	{
		DispatchQueue.main.async
		{
			#if os(macOS)
			self.needsDisplay = true
			#elseif os(iOS)
			self.setNeedsDisplay()
			#endif
		}
	}

	/// Updates the view's display to the given `buffer`
	public func update(buffer: ImageBuffer<Color>)
	{
		setFrameBuffer(buffer)
		present()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// General frame buffer management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initializes the `frameBuffer` as default, which has a Grayscale pyramid-like appeaerance
	///
	/// This method will ensure that `frameBuffer` is a `kDefaultDimension`x`kDefaultDimension` image
	public func initDefaultImage()
	{
		ensureFrameBufferDimensions(width: RenderView.kDefaultDimension, height: RenderView.kDefaultDimension)

		guard let frameBuffer = frameBuffer else { return }

		// Dimension -> intensity scale
		let scale = Float(256) / Float(RenderView.kDefaultDimension)

		for y in 0..<frameBuffer.height
		{
			for x in 0..<frameBuffer.width
			{
				// Orthogonal distance from center
				let d = max(abs(y-RenderView.kDefaultDimension/2), abs(x-RenderView.kDefaultDimension/2))

				// Apply scale
				let c = UInt32(Float(d) * scale * 1.5)
				frameBuffer.buffer[y * RenderView.kDefaultDimension + x] = 0xff000000 | (c<<16) | (c<<8) | c
			}
		}
	}

	/// Replaces the contents of `frameBuffer` with the given `buffer`. This is a copy operation and does not require that `buffer`
	/// remain resident and alive.
	///
	/// If `frameBuffer` does not already exist, or the dimensions do not match the input `buffer`, then `frameBuffer` is
	/// (re-)created in order to receive the copy.
	public func setFrameBuffer(_ buffer: ImageBuffer<Color>)
	{
		ensureFrameBufferDimensions(width: buffer.width, height: buffer.height)
		frameBuffer?.copy(from: buffer)
	}

	#if os(macOS)
	/// Writes the frame buffer to the given path, with an option to number the files.
	///
	/// See `writePng` for details on how `path` and `numbered` are used.
	///
	/// If there is no `frameBuffer`, then this method does nothing
	public func writeFrameBuffer(to path: PathString, numbered: Bool = true)
	{
		do
		{
			try frameBuffer?.writePng(to: path, numbered: numbered)
		}
		catch
		{
			gLogger.error("Failed writing debug.png file: \(error.localizedDescription)")
		}
	}
	#endif

	/// Ensures that `frameBuffer` exists has the given dimensions
	///
	/// If the current `frameBuffer` dimensions do not match the input dimensions, then `frameBuffer` is recreated and the existing
	/// contents are lost.
	private func ensureFrameBufferDimensions(width: Int, height: Int)
	{
		if frameBuffer == nil || frameBuffer!.width != width || frameBuffer!.height != height
		{
			frameBuffer = ImageBuffer<Color>(width: width, height: height)
		}
	}

	/// Returns the context
	public func getContext() -> CGContext?
	{
		#if os(macOS)
		return NSGraphicsContext.current?.cgContext
		#else
		return UIGraphicsGetCurrentContext()
		#endif
	}
}

#endif // #if os(macOS) || os(iOS)
