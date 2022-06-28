//
//  SampleLine.swift
//  Seer
//
//  Created by pn on 12/6/16.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

// ---------------------------------------------------------------------------------------------------------------------------------
// Global types
// ---------------------------------------------------------------------------------------------------------------------------------

/// The sample data type
///
/// This represents a sample as data, rather than as a color or luminosity value
///
/// This is a signed value
public typealias Sample = Int32

/// A collection of image samples captured along a line through image-space.
public final class SampleLine
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Local constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Scalar applied to known capacities for allocation during re-use. This causes our allocator to become greedy in order to
	/// reduce allocations needed.
	private static let kGreedyAllocationScalar: FixedPoint = 2

	// -----------------------------------------------------------------------------------------------------------------------------
	// Properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// The starting point for the sample line
	var p0: IVector

	/// The end point for the sample line
	var p1: IVector

	/// If sampled, contains the captured samples along the line (p0, p1)
	var samples = UnsafeMutableArray<Sample>()

	/// Returns the number of samples captured by the SampleLine (convenient access to `samples.count`)
	var sampleCount: Int
	{
		return samples.count
	}

	/// Returns the center point of the SampleLine.
	///
	/// As this is an integer operation, the result may not be exact. In these cases, the X/Y component will lean toward zero.
	var center: IVector
	{
		return (p0 + p1) / 2
	}

	/// Returns a orthogonal normal that is counterclockwise of the direction of the vector
	///
	/// see Point.orthoNormal for details
	var orthoNormal: IVector
	{
		return (p1 - p0).orthoNormal
	}

	/// Returns a perpendicular orthogonal normal that is counterclockwise of the direction of the vector
	///
	/// see Point.perpOrthoNormal for details
	var perpOrthoNormal: IVector
	{
		return (p1 - p0).perpOrthoNormal
	}

	/// Returns the length of the line, in terms of the number of pixels that would be interpolated for sampling
	var interpolatedLength: Int
	{
		return (p1 - p0).abs().max() + 1
	}

	/// Returns an integer vector of the line
	var vector: IVector
	{
		return p1 - p0
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initializes a sample line with zeroed points
	init()
	{
		p0 = IVector()
		p1 = IVector()
	}

	/// Initializes the sample line from a set of IVectors
	init(p0: IVector, p1: IVector)
	{
		self.p0 = p0
		self.p1 = p1
	}

	/// Initializes the sample line another sampleLine
	///
	/// NOTE: The new SampleLine will allocate and copy the original set of samples if they exist, which can be expensive. To avoid
	/// this, use init(p0:p1) instead.
	init(_ rhs: SampleLine)
	{
		self.p0 = rhs.p0
		self.p1 = rhs.p1
		self.samples = UnsafeMutableArray(rhs.samples)
	}

	/// Initializes a sample line with custom data from a single row of a StaticMatrix
	///
	/// This can be useful when generating a series of sample lines in which column represents the data for a SampleLine
	init(p0: IVector, p1: IVector, withMatrix matrix: StaticMatrix<Sample>, rowIndex: Int)
	{
		self.p0 = p0
		self.p1 = p1
		self.samples = UnsafeMutableArray(withData: matrix[rowIndex], count: matrix.colCount(row: rowIndex))
	}

	/// Releases all resources used by the SampleLine
	deinit
	{
		free()
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Conversion
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Initializes the sample line from a Line
	///
	/// Note that the points from Line are chopped to integer points (not rounded)
	init(line: Line)
	{
		p0 = line.p0.chopToPoint()
		p1 = line.p1.chopToPoint()
	}

	/// Converts the SampleLine into a Line
	func toLine() -> Line
	{
		return Line(p0: p0, p1: p1)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Clipping
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Clip the line to given rectangle
	///
	/// The routine returns a new SampleLine representing the clipped portion, or nil if the line does not intersect the given
	/// rectangle. Note that the new SampleLine is comprised only of points and will not contain any sample data.
	func clipped(to rect: Rect<Int>) -> SampleLine?
	{
		let sampleLine = SampleLine(p0: p0, p1: p1)
		if !sampleLine.clip(to: rect) { return nil }
		return sampleLine
	}

	/// Clip the line to given rectangle
	///
	/// The routine returns false if the line does not intersect the rectangle.
	func clip(to rect: Rect<Int>) -> Bool
	{
		let dx = p1.x - p0.x
		let dy = p1.y - p0.y

		// Clip on DX
		if dx > 0
		{
			if p0.x < rect.minX || p1.x > rect.maxX
			{
				if p1.x < rect.minX || p0.x > rect.maxX { return false }
				let dyx = dy.toFixed() / dx
				if p0.x < rect.minX { p0.y += (dyx * (rect.minX - p0.x)).floor(); p0.x = rect.minX }
				if p1.x > rect.maxX { p1.y -= (dyx * (p1.x - rect.maxX)).floor(); p1.x = rect.maxX }
			}
		}
		else if dx < 0
		{
			if p1.x < rect.minX || p0.x > rect.maxX
			{
				if p0.x < rect.minX || p1.x > rect.maxX { return false }
				let dyx = dy.toFixed() / dx
				if p1.x < rect.minX { p1.y += (dyx * (rect.minX - p1.x)).floor(); p1.x = rect.minX }
				if p0.x > rect.maxX { p0.y -= (dyx * (p0.x - rect.maxX)).floor(); p0.x = rect.maxX }
			}
		}
		else // dx == 0
		{
			if p1.x < rect.minX || p0.x > rect.maxX { return false }
		}

		// Clip on DY
		if dy > 0
		{
			if p0.y < rect.minY || p1.y > rect.maxY
			{
				if p1.y < rect.minY || p0.y > rect.maxY { return false }
				let dxy = dx.toFixed() / dy
				if p0.y < rect.minY { p0.x += (dxy * (rect.minY - p0.y)).floor(); p0.y = rect.minY }
				if p1.y > rect.maxY { p1.x -= (dxy * (p1.y - rect.maxY)).floor(); p1.y = rect.maxY }
			}
		}
		else if dy < 0
		{
			if p1.y < rect.minY || p0.y > rect.maxY
			{
				if p0.y < rect.minY || p1.y > rect.maxY { return false }
				let dxy = dx.toFixed() / dy
				if p1.y < rect.minY { p1.x += (dxy * (rect.minY - p1.y)).floor(); p1.y = rect.minY }
				if p0.y > rect.maxY { p0.x -= (dxy * (p0.y - rect.maxY)).floor(); p0.y = rect.maxY }
			}
		}
		else // dy == 0
		{
			if p1.y < rect.minY || p0.y > rect.maxY { return false }
		}

		return true
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Drawing
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Draws a line to the given ImageBuffer
	///
	/// Implementation notes:
	///
	/// Our fractional deltas (using FixedPoint) will error on the side of being slightly smaller than the actual
	/// (perfectly (precise) value. As a result, the coordinate that gets stepped from by these values may not end up
	/// reaching the very end.
	///
	/// Since we start with coordinates that are floored to integer boundaries, the final value for the coordinates being
	/// stepped with a fractional deltas should land on the exact integer boundary of the final pixel. For example, a
	/// value that should step to 1080.0 may only step to 1079.997.
	///
	/// The solution is to predict this error (multiply our delta by the number of steps we'll take) and subtract that
	/// from the expected final value. This effectively calculates an exact epsilon. By adding this to the starting
	/// point, we ensure that we'll land on the exact pixel we intend to.
	func draw(to image: DebugBuffer?, color: Color)
	{
		if let samples = image?.buffer
		{
			// Clip and chop our line
			guard let line = clipped(to: image!.rect) else { return }

			let p0 = line.p0
			let p1 = line.p1

			// Deltas
			let dx = p1.x - p0.x
			let dy = p1.y - p0.y
			let absDX = abs(dx)
			let absDY = abs(dy)
			let width = image!.width

			// Primarily horizontal
			if absDX >= absDY
			{
				var x = p0.x
				var y = p0.y.toFixed() + FixedPoint.kHalf
				let endX = p1.x
				let endY = p1.y.toFixed() + FixedPoint.kHalf
				let xStep = dx >= 0 ? 1 : -1
				let yStep = absDX == 0 ? 0 : dy.toFixed() / absDX

				// Calculate our error epsilon and add it to the starting point
				y += endY - (y + yStep * absDX)

				let ty = y.floor()
				samples[ty * width + x] = alphaBlend(src: color, dst: samples[ty * width + x])
				while x != endX
				{
					y += yStep
					x += xStep
					let ty = y.floor()
					samples[ty * width + x] = alphaBlend(src: color, dst: samples[ty * width + x])
				}
			}
			// Primarily vertical
			else // dy.abs() > dx.abs()
			{
				var x = p0.x.toFixed() + FixedPoint.kHalf
				var y = p0.y * width
				let endX = p1.x.toFixed() + FixedPoint.kHalf
				let endY = p1.y * width
				let xStep = absDY == 0 ? 0 : dx.toFixed() / absDY
				let yStep = dy >= 0 ? width : -width

				// Calculate our error epsilon and add it to the starting point
				x += endX - (x + xStep * absDY)

				let tx = x.floor()
				samples[y + tx] = alphaBlend(src: color, dst: samples[y + tx])
				while y != endY
				{
					y += yStep
					x += xStep
					let tx = x.floor()
					samples[y + tx] = alphaBlend(src: color, dst: samples[y + tx])
				}
			}
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Sample capture
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Releases all resources used by the SampleLine
	@inline(__always) func free()
	{
		samples.free()
	}

	/// Resets the sampler to a state prior to calling sample() and optionally ensures enough memory is allocated to the SampleLine
	/// to meet `suggestedCapacity`.
	///
	/// The allocated memory will be automatically released when the SampleLine is de-initialized. However, `free()` can be used to
	/// force an early release of all allocated memory.
	///
	/// Allocation strategy and re-use
	///
	/// The first time a SampleLine is sampled (i.e., there is no reserved capacity) the `suggestedCapacity` is allocated. If the
	/// SampleLine is re-used (i.e., there is a previously reserved capacity), then it is assumed that this SampleLine will be
	/// re-used multiple times.
	///
	/// In the case of re-use, a re-allocation may be necessary if the `reservedCapacity` does not meet the `suggestedCapacity`.
	/// When a reallocation is needed, the SampleLine's memory requirements from use to use are unknown and a greedy allocation
	/// strategy is used to minimize allocations performed. This greedy strategy causes allocations to exceed `suggestedCapacity`.
	/// As `suggestedCapacity` is still a useful indicator of the expected usage, a scalar (SampleLine.kGreedyAllocationScalar) is
	/// applied to `suggestedCapacity` and the result is used for allocation.
	@inline(__always) private func prepareSampler(suggestedCapacity: Int)
	{
		samples.ensureReservation(capacity: suggestedCapacity, growthScalar: SampleLine.kGreedyAllocationScalar)
	}

	/// Collects samples along the line from the given ImageBuffer
	///
	/// It is important to take note that the line may be clipped as part of this operation, which has two side-effects that should
	/// be handled by callers:
	///
	///		1. As this method is generally used to sample a discreet portion of an image, callers should be aware that the
	///		   endpoints of the line could change as a result of calling this method.
	///		2. The portion of the image actually sampled will change relative to the outcome of the clipping process.
	///
	/// To put it more succinctly, if a caller expects to sample a portion of an image and then expects to extract data from that
	/// sampled line at a given offset, that offset would need to be adjusted to the potentially clipped line, as well as validated
	/// to be part of the clipped line.
	///
	/// This routine will return false if the given SampleLine does not intersect the image rectangle
	///
	/// Implementation notes:
	///
	/// See `draw(to:color:)` for more information
	func sample(from image: LumaBuffer, invertSampleLuma: Bool, p0 inP0: IVector? = nil, p1 inP1: IVector? = nil) -> Bool
	{
		// Are we given a new set of points?
		if inP0 != nil || inP1 != nil
		{
			if inP0 != nil { p0 = inP0! }
			if inP1 != nil { p1 = inP1! }
		}

		// Clip our line
		if !clip(to: image.rect) { return false }

		// Get ready...
		prepareSampler(suggestedCapacity: interpolatedLength)

		// Deltas
		let dx = p1.x - p0.x
		let dy = p1.y - p0.y
		let absDX = abs(dx)
		let absDY = abs(dy)
		let width = image.width

		// Primarily horizontal
		let src = image.buffer
		if absDX >= absDY
		{
			var x = p0.x
			var y = p0.y.toFixed() + FixedPoint.kHalf
			let endX = p1.x
			let endY = p1.y.toFixed() + FixedPoint.kHalf
			let xStep = dx >= 0 ? 1 : -1
			let yStep = absDX == 0 ? 0 : dy.toFixed() / absDX

			// Calculate our error epsilon and add it to the starting point
			y += endY - (y + yStep * absDX)

			if invertSampleLuma
			{
				samples.add(Sample(255-src[y.floor() * width + x]))
				while x != endX
				{
					y += yStep
					x += xStep
					samples.add(255-Sample(src[y.floor() * width + x]))
				}
			}
			else
			{
				samples.add(Sample(src[y.floor() * width + x]))
				while x != endX
				{
					y += yStep
					x += xStep
					samples.add(Sample(src[y.floor() * width + x]))
				}
			}
		}
		// Primarily vertical
		else // dy.abs() > dx.abs()
		{
			var x = p0.x.toFixed() + FixedPoint.kHalf
			var y = p0.y * width
			let endX = p1.x.toFixed() + FixedPoint.kHalf
			let endY = p1.y * width
			let xStep = absDY == 0 ? 0 : dx.toFixed() / absDY
			let yStep = dy >= 0 ? width : -width

			// Calculate our error epsilon and add it to the starting point
			x += endX - (x + xStep * absDY)

			if invertSampleLuma
			{
				samples.add(255-Sample(src[y + x.floor()]))
				while y != endY
				{
					x += xStep
					y += yStep
					samples.add(255-Sample(src[y + x.floor()]))
				}
			}
			else
			{
				samples.add(Sample(src[y + x.floor()]))
				while y != endY
				{
					x += xStep
					y += yStep
					samples.add(Sample(src[y + x.floor()]))
				}
			}
		}

		return true
	}

	/// Collects samples along the line from the given ImageBuffer, using a weighted average of the sample line with its neighbors
	///
	/// This method differs from `sample(from:p0:p1:)` (which retrieves a single sample per pixel along the line) in that it will
	/// also retrieve a sample from each of the neighboring lines and perform a weighted average.
	///
	/// Neighboring lines are selected based on the primary direction of the line. If the line is primarily horizontal, then the
	/// neighbor samples are those that are directly above and below each sample along the line. If the line is primarily vertical,
	/// the neighbor samples are those that are directly to the left and right of the sample along the line.
	///
	/// The weighted average prioritizes the center sample (along the 'true line') by giving the center sample twice the weight of
	/// its neighbors within the average result. Specifically: ( f(x-1) + f(x)*2 + f(x+1) ) / 4
	///
	/// In order to account for the additional width of the line, the line is clipped to a rectangle that represents the image
	/// dimensions that have been reduced by one pixel on each of the four borders. This is slightly wasteful as a 'wide' line is
	/// only expanded in one direction (two borders.) However, this is far more efficient.
	///
	/// Implementation notes:
	///
	/// See `draw(to:color:)` for more information
	func sampleWide(from image: LumaBuffer, p0 inP0: IVector? = nil, p1 inP1: IVector? = nil) -> Bool
	{
		let kWideAmount = 2
		// Are we given a new set of points?
		if inP0 != nil || inP1 != nil
		{
			if inP0 != nil { p0 = inP0! }
			if inP1 != nil { p1 = inP1! }
		}

		// Clip our line - note that we reduce the image dimensions by 1 in each direction to account for our wider line. This
		// is slightly wasteful as a 'wide' line is only expanded in one direction (two borders.) However, this is far more
		// efficient.
		if !clip(to: image.rect.reduced(by: kWideAmount)) { return false }

		// Get ready...
		prepareSampler(suggestedCapacity: interpolatedLength)

		// Deltas
		let dx = p1.x - p0.x
		let dy = p1.y - p0.y
		let absDX = abs(dx)
		let absDY = abs(dy)
		let width = image.width

		// Primarily horizontal
		let src = image.buffer
		if absDX >= absDY
		{
			var x = p0.x
			var y = p0.y.toFixed() + FixedPoint.kHalf
			let endX = p1.x
			let endY = p1.y.toFixed() + FixedPoint.kHalf
			let xStep = dx >= 0 ? 1 : -1
			let yStep = absDX == 0 ? 0 : dy.toFixed() / absDX

			// Calculate our error epsilon and add it to the starting point
			y += endY - (y + yStep * absDX)

			samples.add(Sample(src[y.floor() * width + x]))
			let wideWidth = width * kWideAmount
			while x != endX
			{
				y += yStep
				x += xStep
				let idx = y.floor() * width + x
				let a = Int(src[idx - wideWidth])
				let b = Int(src[idx]) * 2
				let c = Int(src[idx + wideWidth])
				samples.add(Sample((a + b + c) / 4))
			}
		}
		// Primarily vertical
		else // dy.abs() > dx.abs()
		{
			var x = p0.x.toFixed() + FixedPoint.kHalf
			var y = p0.y * width
			let endX = p1.x.toFixed() + FixedPoint.kHalf
			let endY = p1.y * width
			let xStep = absDY == 0 ? 0 : dx.toFixed() / absDY
			let yStep = dy >= 0 ? width : -width

			// Calculate our error epsilon and add it to the starting point
			x += endX - (x + xStep * absDY)

			samples.add(Sample(src[y + x.floor()]))
			while y != endY
			{
				y += yStep
				x += xStep
				let idx = y + x.floor()
				let a = Int(src[idx - kWideAmount])
				let b = Int(src[idx]) * 2
				let c = Int(src[idx + kWideAmount])
				samples.add(Sample((a + b + c) / 4))
			}
		}

		return true
	}

	/// Find the center of a mark within the set of samples
	///
	/// Discussion:
	///
	/// The basic idea here is to calculate a weighted average of the X and Y coordinates of each sample, where the weight is
	/// the sample intensity, inverted.
	///
	/// Implementation notes:
	///
	/// See `draw(to:color:)` for more information
	func weightedCenter(from image: LumaBuffer, p0 inP0: IVector? = nil, p1 inP1: IVector? = nil) -> (center: IVector, averageIntensity: Luma)?
	{
		// Are we given a new set of points?
		if inP0 != nil || inP1 != nil
		{
			if inP0 != nil { p0 = inP0! }
			if inP1 != nil { p1 = inP1! }
		}

		// Clip our line
		if !clip(to: image.rect) { return nil }

		// Deltas
		let dx = p1.x - p0.x
		let dy = p1.y - p0.y
		let absDX = abs(dx)
		let absDY = abs(dy)
		let width = image.width

		var sumX = 0
		var sumY = 0
		var sumI = 0
		var cnt = 0

		// Primarily horizontal
		let src = image.buffer
		if absDX >= absDY
		{
			var x = p0.x
			var y = p0.y.toFixed() + FixedPoint.kHalf
			let endX = p1.x
			let endY = p1.y.toFixed() + FixedPoint.kHalf
			let xStep = dx >= 0 ? 1 : -1
			let yStep = absDX == 0 ? 0 : dy.toFixed() / absDX

			// Calculate our error epsilon and add it to the starting point
			y += endY - (y + yStep * absDX)

			var iy = y.floor()
			var i = 255 - Int(src[iy * width + x])
			sumX += i * x
			sumY += i * iy
			sumI += i
			cnt += 1

			while x != endX
			{
				y += yStep
				x += xStep

				iy = y.floor()
				i = 255 - Int(src[iy * width + x])
				sumX += i * x
				sumY += i * iy
				sumI += i
				cnt += 1
			}
		}
		// Primarily vertical
		else // dy.abs() > dx.abs()
		{
			var x = p0.x.toFixed() + FixedPoint.kHalf
			var y = p0.y
			let endX = p1.x.toFixed() + FixedPoint.kHalf
			let endY = p1.y
			let xStep = absDY == 0 ? 0 : dx.toFixed() / absDY
			let yStep = dy >= 0 ? 1 : -1

			// Calculate our error epsilon and add it to the starting point
			x += endX - (x + xStep * absDY)

			var ix = x.floor()
			var i = 255 - Int(src[y * width + ix])
			sumX += i * ix
			sumY += i * y
			sumI += i
			cnt += 1

			while y != endY
			{
				x += xStep
				y += yStep

				ix = x.floor()
				i = 255 - Int(src[y * width + ix])
				sumX += i * ix
				sumY += i * y
				sumI += i
				cnt += 1
			}
		}

		return (IVector(x: sumX / sumI, y: sumY / sumI), Luma(sumI / cnt))
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Sharpness
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Performs a sharpness calculation on the entire sample line.
	///
	/// See `calcMaxSharpnessUnitScalar(debugBuffer:start:count:amplitude:...)` for more information.
	@inline(__always) func calcMaxSharpnessUnitScalar(debugBuffer: DebugBuffer?, minRange: Float, amplitude: Sample, debugRefIndex: Int, debugRefCount: Int) -> FixedPoint
	{
		return calcMaxSharpnessUnitScalar(debugBuffer: debugBuffer, start: 0, count: sampleCount, minRange: minRange, amplitude: amplitude, debugRefIndex: debugRefIndex, debugRefCount: debugRefCount)
	}

	/// Returns a representative value for the sharpness of the sample line for a given range of samples (`start`, `count`) and for
	/// for a given `amplitude` of sample intensities.
	///
	/// `minRange` represents the minimum range of the full set of samples of interest. In terms of decks, it should be set to
	/// the deck's `format.minSampleHeght()`.
	///
	/// `amplitude` represents the the difference between the minimum and maximum intensities of the samples from the input
	/// set (specified by `start` and `count`.) It is used scale the maximum calculated sharpness to the overall intensity range
	/// for a result that is relative to the input samples. For the most accurate results, ensure `sampleRange` is calculated from
	/// the same start/count range. If this is not the case, the return value may not be properly scaled to a unit scalar.
	///
	/// Implementation details:
	///
	///		In order to account for resolution differences, the sharpness calculation works on a set of exactly 'n' pixels,
	///		regardless of the resolution or how tall the deck is within the image. This is calculated based on a deck's minimum
	///		sample height - and that number of samples are sampled during the sharpness calculation. Therefore, it is important
	///		that the `start`/`count` represent just the portion of image that represents a vertical slice of the deck.
	///
	/// Note that the resulting value will closely resemble (1.0) for the middle-ground between blurry and sharp.
	func calcMaxSharpnessUnitScalar(debugBuffer: DebugBuffer?, start: Int, count: Int, minRange: Float, amplitude: Sample, debugRefIndex: Int, debugRefCount: Int) -> FixedPoint
	{
		let sharpnessCount = minRange.floor()
		if amplitude == 0 { return 0 }
		if count < 4 { return 0 }

		let step = FixedPoint(count) / sharpnessCount
		var index = FixedPoint(start)

		var a = samples[index.floor()]; index += step
		var b = samples[index.floor()]; index += step
		var c = samples[index.floor()]; index += step
		var d = samples[index.floor()]; index += step

		var maxDelta: Sample = 0

		// Roll through our samples, calculating a linear sharpness using the kernel: [+1, +1, -1, -1]
		for _ in 4..<sharpnessCount
		{
			let delta = abs(a + b - c - d)
			maxDelta = max(delta, maxDelta)
			a = b
			b = c
			c = d
			d = samples[index.floor()]
			index += step
		}
		let delta = abs(a + b - c - d)
		maxDelta = max(delta, maxDelta)
		let result = maxDelta.toFixed() / amplitude

		if Config.debugDrawSharpnessGraphs && debugBuffer != nil
		{
			let sharpGraphColor = result > Config.decodeMinimumSharpnessUnitScalarThreshold ? Color(integerLiteral: 0x8000ff00) : Color(integerLiteral: 0x804040ff)
			let maxColor = Color(integerLiteral: 0xffff0000)
			let rangeBack = Color(integerLiteral: 0x40000000)

			let chartCountPerSide = debugRefCount / 2
			let centerY = debugBuffer!.height / 2
			let leftSide = debugRefIndex < chartCountPerSide

			let localIndex = debugRefIndex < chartCountPerSide ? debugRefIndex : debugRefIndex - chartCountPerSide

			let chartWidth = sharpnessCount
			let chartHeight = (debugBuffer!.height - 50) / debugRefCount
			let border = chartHeight
			let chartBorderedHeight = chartHeight + border

			let chartBaseX = leftSide ? border : debugBuffer!.width - chartWidth - border
			let chartBaseY = centerY + chartBorderedHeight * chartCountPerSide / 2 - chartBorderedHeight * localIndex

			// Draw the scalar range
			let r = Rect<Int>(x: chartBaseX, y: chartBaseY - chartHeight, width: chartWidth, height: chartHeight + 1)
			r.fill(to: debugBuffer, color: rangeBack)

			// Draw the max range
			let maxOffset = FixedPoint(maxDelta) / amplitude * chartHeight
			SampleLine(p0: IVector(x: chartBaseX, y: chartBaseY - maxOffset.floor()),
			           p1: IVector(x: chartBaseX + chartWidth, y: chartBaseY - maxOffset.floor())
				).draw(to: debugBuffer, color: maxColor)

			var index = FixedPoint(start)

			var a = samples[index.floor()]; index += step
			var b = samples[index.floor()]; index += step
			var c = samples[index.floor()]; index += step
			var d = samples[index.floor()]; index += step

			// Roll through our samples, calculating a linear sharpness using the kernel: [+1/2, +1/2, -1/2, -1/2]
			for i in 4..<sharpnessCount
			{
				let delta = abs(a + b - c - d)
				let val = FixedPoint(delta) / amplitude * chartHeight
				a = b
				b = c
				c = d
				d = samples[index.floor()]
				index += step

				let p0 = IVector(x: chartBaseX + i, y: chartBaseY - val.floor())
				let p1 = IVector(x: chartBaseX + i, y: chartBaseY)
				SampleLine(p0: p0, p1: p1).draw(to: debugBuffer, color: sharpGraphColor)
				p0.draw(to: debugBuffer, color: sharpGraphColor | 0xff000000)
			}

			let delta = abs(a + b - c - d)
			let val = FixedPoint(delta) / amplitude * chartHeight
			let p0 = IVector(x: chartBaseX - start + sharpnessCount, y: chartBaseY - val.floor())
			let p1 = IVector(x: chartBaseX - start + sharpnessCount, y: chartBaseY)
			SampleLine(p0: p0, p1: p1).draw(to: debugBuffer, color: sharpGraphColor)
			p0.draw(to: debugBuffer, color: sharpGraphColor | 0xff000000)
		}

		return result
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Extend the SampleLine in both directions by a given distance
	///
	/// Note that the resulting line length will be (initial_length + distance * 2)
	func extend(distance: Int)
	{
		if distance == 0 { return }

		let delta = (p1 - p0).toVector().ofLength(Real(distance)).roundToPoint()
		p0 -= delta
		p1 += delta
	}

	/// Returns an extended SampleLine (see extend(distance:))
	///
	/// This method will always return a new line, even if the new line is the same length (distance == 0)
	///
	/// Note that the new sample line will not capture the samples from the original. It will have a sampleCount of 0 and no
	/// sample data.
	func extended(distance: Int) -> SampleLine
	{
		let sampleLine = SampleLine(p0: p0, p1: p1)
		sampleLine.extend(distance: distance)
		return sampleLine
	}

	/// Extend the SampleLine in both directions by a given ratio of the distance
	///
	/// Note that this is the extension ratio, so a value of 0.5 will increase each end of the line by half (0.5) of the current
	/// length of the line. A value of zero will not alter the line.
	///
	/// Note that the resulting line length will be (initial_length + distance * 2)
	func extend(ratio: Real)
	{
		let dist = (Real(interpolatedLength) * ratio).roundToNearest()
		if dist == 0 { return }
		extend(distance: dist)
	}

	/// Returns an extended SampleLine (see extend(ratio:))
	func extended(ratio: Real) -> SampleLine
	{
		let sampleLine = SampleLine(p0: p0, p1: p1)
		sampleLine.extend(ratio: ratio)
		return sampleLine
	}

	/// Returns the point along the SampleLine where the given sample offset would be interpolated
	@inline(__always) func interpolationPoint(sampleOffset: Int) -> IVector
	{
		// NOTE: This routine uses a reduced and optimized version of the math in sample()
		let dx = p1.x - p0.x
		let dy = p1.y - p0.y
		let absDX = abs(dx)
		let absDY = abs(dy)

		// Primarily horizontal
		if absDX >= absDY
		{
			var y = p0.y.toFixed() + FixedPoint.kHalf
			let endY = p1.y.toFixed() + FixedPoint.kHalf
			let xStep = dx >= 0 ? 1 : -1
			let yStep = absDX == 0 ? 0 : dy.toFixed() / absDX

			// Calculate our error epsilon and add it to the starting point
			let x = p0.x + xStep * sampleOffset
			y += endY - (y + yStep * absDX) + yStep * sampleOffset
			return IVector(x: x, y: y.floor())
		}
		// Primarily vertical
		else // dy.abs() > dx.abs()
		{
			var x = p0.x.toFixed() + FixedPoint.kHalf
			let endX = p1.x.toFixed() + FixedPoint.kHalf
			let xStep = absDY == 0 ? 0 : dx.toFixed() / absDY
			let yStep = dy >= 0 ? 1 : -1

			// Calculate our error epsilon and add it to the starting point
			x += endX - (x + xStep * absDY) + xStep * sampleOffset
			let y = p0.y + yStep * sampleOffset
			return IVector(x: x.floor(), y: y)
		}
	}

	// Returns the average sample value for the entire sample line
	func calcAverage() -> Sample
	{
		if sampleCount == 0
		{
			return 0
		}

		var sum: Sample = 0
		for i in 0..<sampleCount
		{
			sum += samples[i]
		}

		return sum / Sample(sampleCount)
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: String representation
// ---------------------------------------------------------------------------------------------------------------------------------

extension SampleLine: CustomStringConvertible, CustomDebugStringConvertible
{
	public var debugDescription: String
	{
		return description
	}

	public var description: String
	{
		var str = "(\(String(describing: p0))) - (\(String(describing: p1))) SampleCount:\(sampleCount)"
		if sampleCount > 0
		{
			str += String.kNewLine
			for i in 0..<sampleCount
			{
				str += String(format: "%2X", arguments: [Int(samples[i])])
			}
		}
		return str
	}
}

// -----------------------------------------------------------------------------------------------------------------------------
// Extension: Equatable
// -----------------------------------------------------------------------------------------------------------------------------

extension SampleLine: Equatable
{
	/// Returns a Boolean value indicating whether two values are equal.
	public static func == (lhs: SampleLine, rhs: SampleLine) -> Bool
	{
		if lhs.sampleCount != rhs.sampleCount { return false }
		for i in 0..<lhs.sampleCount
		{
			if lhs.samples[i] != rhs.samples[i] { return false }
		}

		return true
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Extension: Arithmetic operations
// ---------------------------------------------------------------------------------------------------------------------------------

extension SampleLine
{
	static func + (left: SampleLine, right: Int) -> SampleLine
	{
		return SampleLine(p0: left.p0 + right, p1: left.p1 + right)
	}

	static func + (left: SampleLine, right: IVector) -> SampleLine
	{
		return SampleLine(p0: left.p0 + right, p1: left.p1 + right)
	}

	static func + (left: SampleLine, right: SampleLine) -> SampleLine
	{
		return SampleLine(p0: left.p0 + right.p0, p1: left.p1 + right.p1)
	}

	static func - (left: SampleLine, right: Int) -> SampleLine
	{
		return SampleLine(p0: left.p0 - right, p1: left.p1 - right)
	}

	static func - (left: SampleLine, right: IVector) -> SampleLine
	{
		return SampleLine(p0: left.p0 - right, p1: left.p1 - right)
	}

	static func - (left: SampleLine, right: SampleLine) -> SampleLine
	{
		return SampleLine(p0: left.p0 - right.p0, p1: left.p1 - right.p1)
	}

	static func * (left: SampleLine, right: Int) -> SampleLine
	{
		return SampleLine(p0: left.p0 * right, p1: left.p1 * right)
	}

	static func * (left: SampleLine, right: IVector) -> SampleLine
	{
		return SampleLine(p0: left.p0 * right, p1: left.p1 * right)
	}

	static func * (left: SampleLine, right: SampleLine) -> SampleLine
	{
		return SampleLine(p0: left.p0 * right.p0, p1: left.p1 * right.p1)
	}

	static func / (left: SampleLine, right: Int) -> SampleLine
	{
		return SampleLine(p0: left.p0 / right, p1: left.p1 / right)
	}

	static func / (left: SampleLine, right: IVector) -> SampleLine
	{
		return SampleLine(p0: left.p0 / right, p1: left.p1 / right)
	}

	static func / (left: SampleLine, right: SampleLine) -> SampleLine
	{
		return SampleLine(p0: left.p0 / right.p0, p1: left.p1 / right.p1)
	}
}
