//
//  ImageBuffer-ImageProcessing.swift
//  Seer
//
//  Created by Paul Nettle on 2/26/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
#if os(iOS)
import NativeTasksIOS
#else
import NativeTasks
#endif
#if os(Linux)
import C_ncurses
#endif

struct Motion
{
	static var prevFrame = LumaBuffer(width: 256, height: 256)
	static var thisFrame = LumaBuffer(width: 256, height: 256)
}

/// Extension to add image processing functionality to ImageBuffer
extension ImageBuffer where Sample == Luma
{
	// Image preprocessing adjustments for the Luma buffer
	public func preprocess()
	{
		// If we are replaying, we've already preprocessed the frame
		if Config.isReplayingFrame { return }

		if Config.testbedFilterInputHistogramNormalization
		{
			normalize()
		}

		if Config.testbedFilterInputContrastEnhance
		{
			contrastAdjustSamples(amount: 0.3)
		}

		if Config.testbedFilterInputBoxFilter
		{
			boxFilter()
		}

		if Config.testbedFilterInputLowPass
		{
			lowPass(debugGeneralPurposeParameter: Config.debugGeneralPurposeParameter)
		}

		if Config.debugRotateFrame
		{
			rotate180()
		}
	}

	private func rotate180()
	{
		nativeRotate180(buffer, UInt32(width), UInt32(height))

		// let halfHeight = height / 2
		// let halfWidth = width / 2
		// for y in 0..<halfHeight
		// {
		// 	let topLine = buffer + width * y
		// 	let botLine = buffer + width * (height - y - 1)
		// 	for x in 0..<halfWidth
		// 	{
		// 		let ltmp = topLine[x]
		// 		let rtmp = topLine[width - x - 1]
		// 		topLine[x] = botLine[width - x - 1]
		// 		topLine[width - x - 1] = botLine[x]
		// 		botLine[x] = rtmp
		// 		botLine[width - x - 1] = ltmp
		// 	}
		// }
	}

	private func lowPass(debugGeneralPurposeParameter: Int, radius: Int = 5)
	{
		var r = max(0, radius + debugGeneralPurposeParameter)
		r = min(height / 2 - 2, r)
		let lpBuf = doLowPass(radius: r)

		// Specialization of Luma
		let total = width * height
		for i in 0..<total
		{
			buffer[i] = lpBuf[i]
		}
	}

	private func doLowPass(radius: Int = 5) -> [Luma]
	{
		var interBuf = [Luma](repeating: 200, count: width * height)
		var outBuf = [Luma](repeating: 200, count: width * height)

		try? interBuf.withUnsafeMutableBufferPointer
		{ (inter: inout UnsafeMutableBufferPointer<Luma>) throws in

			try? outBuf.withUnsafeMutableBufferPointer
			{ (out: inout UnsafeMutableBufferPointer<Luma>) throws in

				let radius2 = radius * 2
				let avgCount = radius2 + 1

				// Vertical pass
				for x in 0..<width
				{
					// Sum the full set of initial values for (radius + center-sample + radius)
					var head = buffer + x
					var sum = 0
					for _ in 0...radius2
					{
						sum += Int(head[0])
						head += width
					}

					// Head points at the next incoming sample
					//
					// Point tail at the next outgoing sample (the first sample in the set)
					var tail = buffer + x

					// Our first output sample, one radius distance into the set
					var dst = inter.baseAddress! + x + radius * width

					// Store the first average and advance
					dst[0] = Luma(sum / avgCount)
					dst += width

					// Scan the rest of the set
					for _ in radius2+1..<height
					{
						// Roll
						sum += Int(head[0])
						sum -= Int(tail[0])
						dst[0] = Luma(sum / avgCount)

						head += width
						tail += width
						dst += width
					}
				}

				// Horizontal pass
				for y in 0..<height
				{
					// Sum the full set of initial values for (radius + center-sample + radius)
					var head = inter.baseAddress! + y * width
					var sum = 0
					for _ in 0...radius2
					{
						sum += Int(head[0])
						head += 1
					}

					// Head points at the next incoming sample
					//
					// Point tail at the next outgoing sample (the first sample in the set)
					var tail = inter.baseAddress! + y * width

					// Our first output sample, one radius distance into the set
					var dst = out.baseAddress! + y * width + radius

					// Store the first average and advance
					dst[0] = Luma(sum / avgCount)
					dst += 1

					// Scan the rest of the set
					for _ in radius2+1..<width
					{
						// Roll
						sum += Int(head[0])
						sum -= Int(tail[0])
						dst[0] = Luma(sum / avgCount)

						head += 1
						tail += 1
						dst += 1
					}
				}
			}
		}

		return outBuf
	}

	private func boxFilter()
	{
		// Vertical pass
		for x in 0..<width
		{
			var ptr = buffer + x
			var a = 0
			var b = Int(ptr[0]); ptr += width
			var c = Int(ptr[0])
			for _ in 1..<height-1
			{
				a = b; b = c; c = Int(ptr[width])
				ptr[0] = Luma((a + b + c) / 3)
				ptr += width
			}
		}
		// Horizontal pass
		for y in 0..<height
		{
			var ptr = buffer + y * width
			var a = 0
			var b = Int(ptr[0]); ptr += 1
			var c = Int(ptr[0])
			for _ in 1..<width-1
			{
				a = b; b = c; c = Int(ptr[1])
				ptr[0] = Luma((a + b + c) / 3)
				ptr += 1
			}
		}
	}

	private func erosionFilter()
	{
		// Vertical pass
		for x in 0..<width
		{
			var ptr = buffer + x
			var a = 0
			var b = Int(ptr[0]); ptr += width
			var c = Int(ptr[0])
			for _ in 1..<height-1
			{
				a = b; b = c; c = Int(ptr[width])
				ptr[0] = Luma(min(a, min(b, c)))
				ptr += width
			}
		}
		// Horizontal pass
		for y in 0..<height
		{
			var ptr = buffer + y * width
			var a = 0
			var b = Int(ptr[0]); ptr += 1
			var c = Int(ptr[0])
			for _ in 1..<width-1
			{
				a = b; b = c; c = Int(ptr[1])
				ptr[0] = Luma(min(a, min(b, c)))
				ptr += 1
			}
		}
	}

	private func brightenSamples(x: Int, y: Int, count: Int, amount: Int)
	{
		let buf = buffer + y * width + x
		for i in 0..<count
		{
			buf[i] = Luma(min(255, Int(buf[i]) + amount))
		}
	}

	private func darkenSamples(x: Int, y: Int, count: Int, amount: Int)
	{
		let buf = buffer + y * width + x
		for i in 0..<count
		{
			buf[i] = Luma(max(0, Int(buf[i]) - amount))
		}
	}

	private func sharpness(x0: Int, y0: Int, x1: Int, y1: Int, dstImage: DebugBuffer) -> Real
	{
		assert(x0 < x1)
		assert(y0 < y1)
		assert(x0 >= 0)
		assert(y0 >= 0)
		assert(x1 < width)
		assert(y1 < height)
		assert(width == dstImage.width)
		assert(height == dstImage.height)

		var clarity: Real = 0

		// Perform a Laplacian filter with the kernel:
		//
		//      1
		//   1 -4  1
		//      1
		//
		//
		// We'll also build a histogram of the filtered values
		var histogram = Array(repeating: 0, count: 256)

		let alphaMask = Color(integerLiteral: 0xff000000)

		for y in y0...y1
		{
			let yMid = y    * width
			let yNeg = yMid - width
			let yPos = yMid + width
			for x in x0...x1
			{
				let yMidX = yMid + x
				var filter = Int(buffer[yNeg + x])
				filter += Int(buffer[yMidX - 1])
				filter -= Int(buffer[yMidX    ]) * 4
				filter += Int(buffer[yMidX + 1])
				filter += Int(buffer[yPos  + x])
				let sample = clamp(filter, 0, 255)
				let cSample = Color(sample)

				var dst = cSample << 16
				dst |= cSample << 8
				dst |= cSample

				dstImage.buffer[yMidX] = dst | alphaMask
				histogram[sample] += 1
			}
		}

		// The histogram serves two purposes: One for visual display, one for finding the focal clarity of
		// the image.
		//
		// In order to display the histogram, we'll need to scale it, which requires the max value of the
		// histogram.
		//
		// In order to find the focal point, we simply track the largest histogram value which is non-zero.
		var maxHistValue = histogram[0]
		var clarityIndex = 0
		for i in 1..<256
		{
			let val = histogram[i]
			if val > 0
			{
				clarityIndex = i
				if val > maxHistValue { maxHistValue = val }
			}
		}

		// Scale & draw the histogram
		let histScalar = Real(255.0) / Real(maxHistValue)
		let histBase = (height - 1) * width + width / 2 - 128
		for x in 0..<256
		{
			// Scale
			let histVal = Int(Real(histogram[x]) * histScalar)

			// Draw
			let col = histBase + x
			for y in 0...histVal
			{
				dstImage.buffer[col - y * width] = 0xffffffff
			}
			for y in histVal...255
			{
				dstImage.buffer[col - y * width] = (dstImage.buffer[col - y * width] >> 1) & 0x007f7f7f | 0xff000000
			}
		}

		clarity = Real(clarityIndex) / 255.0

		// Draw the clarity line
		let clarityBase = histBase - clarityIndex * width
		for x in 0..<256
		{
			dstImage.buffer[clarityBase + x] = 0xff00ff00
		}

		return clarity
	}

	private func normalize()
	{
		// Specialization of Luma
		var minPix = buffer[0]
		var maxPix = minPix
		let count = width * height
		for i in 1..<count
		{
			let pix = buffer[i]
			minPix = min(pix, minPix)
			maxPix = max(pix, maxPix)
		}

		// Ensure we have a delta to work with (without this, we end up with a divide-by-zero error below)
		if minPix == maxPix { return }

		let spread = Real(maxPix - minPix)
		let scalar = Real(255.0 / spread)
		for i in 0..<count
		{
			buffer[i] = Luma(Real(Int(buffer[i]) - Int(minPix)) * scalar)
		}
	}

	private func contrastAdjustSamples(amount: Real)
	{
		var minPix = buffer[0]
		var maxPix = minPix
		let count = width * height
		for i in 1..<count
		{
			let pix = buffer[i]
			minPix = min(pix, minPix)
			maxPix = max(pix, maxPix)
		}

		let spread = Real(maxPix - minPix)
		let minRange = Real(minPix) + spread / 2.0 * amount
		let maxRange = Real(maxPix) - spread / 2.0 * amount

		let scalar = Real(255) / (maxRange - minRange)
		for i in 0..<count
		{
			let newSample = Int((Real(buffer[i]) - minRange) * scalar)
			buffer[i] = Luma(min(max(newSample, 0), 255))
		}
	}
}

extension ImageBuffer where Sample == Color
{
	// Image preprocessing adjustments for the Color buffer
	public func preprocess(lumaBuffer: LumaBuffer)
	{
		if Config.testbedFilterInputHackMap
		{
			hackMap(lumaBuffer: lumaBuffer)
		}
	}

	// Generic hack map function, used to try various image processing techniques
	private func hackMap(lumaBuffer: LumaBuffer)
	{
		let kBlockSize = 64
		let yBlocks = height / kBlockSize
		let xBlocks = width / kBlockSize

		for yb in 0..<yBlocks
		{
			for xb in 0..<xBlocks
			{
				var pixMin = 255
				var pixMax = 0
				var pixSum = 0
				for y in 0..<kBlockSize
				{
					for x in 0..<kBlockSize
					{
						let pix = Int(lumaBuffer.buffer[(yb * kBlockSize + y) * width + xb * kBlockSize + x])
						pixMin = min(pixMin, pix)
						pixMax = max(pixMax, pix)
						pixSum += pix
					}
				}

				let pixAvg = pixSum / (kBlockSize * kBlockSize)
				let minLim = pixMin + (pixAvg - pixMin) / 4
				let maxLim = pixMax - (pixMax - pixAvg) / 4

				var outCount = 0
				if maxLim - minLim < 32
				{
					outCount += kBlockSize * kBlockSize
				}
				else
				{
					for y in 0..<kBlockSize
					{
						for x in 0..<kBlockSize
						{
							let pix = Int(lumaBuffer.buffer[(yb * kBlockSize + y) * width + xb * kBlockSize + x])
							if pix > minLim && pix < maxLim { outCount += 1 }
						}
					}
				}

				if outCount > kBlockSize * kBlockSize - kBlockSize * kBlockSize / 8
				{
					for y in 0..<kBlockSize
					{
						for x in 0..<kBlockSize
						{
							buffer[(yb * kBlockSize + y) * width + xb * kBlockSize + x] = 0x00000020
						}
					}
				}
			}
		}
	}

	private func motionDetector(lumaBuffer: LumaBuffer)
	{
		Motion.prevFrame.copy(from: Motion.thisFrame)
		let prevBuf = Motion.prevFrame.buffer

		Motion.thisFrame.copy(from: lumaBuffer.buffer, width: lumaBuffer.width, height: lumaBuffer.height)
		let thisBuf = Motion.thisFrame.buffer

		//let dbgBuf = buffer

		var totalError = 0
		for y in 0..<256
		{
			let yOffset = y * 256
			//let zOffset = y * width
			for x in 0..<256
			{
				let diff = abs(Int(thisBuf[x+yOffset]) - Int(prevBuf[x+yOffset]))
				totalError += diff
				//let limit = max(min(diff + 128, 255), 0)
				//var pix = Color(limit)
				//pix = pix | (pix << 16) | (pix << 8) | 0xff000000
				//dbgBuf[x+zOffset] = pix
			}
		}

		let metric = Double(totalError) / 256 / 256

		#if os(Linux) || os(macOS)
		if metric > 2
		{
			beep()
		}
		#endif
	}

	private func brightenSamples(x: Int, y: Int, count: Int, amount: Int)
	{
		let amt = Color(amount)
		let buf = buffer + y * width + x
		for i in 0..<count
		{
			let pix = Color(buf[i])

			let a = pix & 0xff000000

			var r = (pix & 0x0000ff) + amt
			r = min(0x0000ff, r)

			var g = (pix & 0x00ff00) + (amt <<  8)
			g = min(0x00ff00, g)

			var b = (pix & 0xff0000) + (amt << 16)
			b = min(0xff0000, b)

			buf[i] = r | g | b | a
		}
	}

	private func darkenSamples(x: Int, y: Int, count: Int, amount: Int)
	{
		let buf = buffer + y * width + x
		let cAmount = Color(amount)
		for i in 0..<count
		{
			let pix = Color(buf[i])

			let a = pix & 0xff000000

			var r = ((pix >>  0) & 0xff)
			r = max(0, r - cAmount)

			var g = ((pix >>  8) & 0xff)
			g = max(0, g - cAmount) <<  8

			var b = ((pix >> 16) & 0xff)
			b = max(0, b - cAmount) << 16

			buf[i] = a | r | g | b
		}
	}
}
