//
//  ImageBuffer-Files.swift
//  Seer
//
//  Created by Paul Nettle on 5/23/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import Dispatch
#if os(iOS)
import NativeTasksIOS
import MinionIOS
#else
import NativeTasks
import Minion
#endif

#if os(Linux)
import C_libpng
#endif // os(Linux)

// ---------------------------------------------------------------------------------------------------------------------------------
// RAW file support
// ---------------------------------------------------------------------------------------------------------------------------------

extension ImageBuffer
{
	/// Produces a URL for a given `filename` that follows a set of rules for target folder location.
	///
	/// If `createPath` is true, then the final path to the file is created if it does not exist.
	///
	/// The path where `filename` is stored follows this OS-specific ordered procedure:
	///
	///		Linux:
	///			1. If `filename` has path components (relative or otherwise) then it is written virbatim
	///			3. The current working directory
	///			4. - WriteFailure -
	///
	///		macOS:
	///			1. If `filename` has path components (relative or otherwise) then it is written virbatim
	///			2. The user's Desktop directory
	///			3. The user's home directory
	///			4. The current working directory
	///			5. - WriteFailure -
	///
	/// An Optional URL object for the given image file
	internal func locateFilenameURL(for filename: PathString, createPath: Bool = false) -> URL?
	{
		#if os(Linux)
			let initialPath = filename.withoutLastComponent() ?? PathString.currentDirectory()
		#else
			let initialPath = filename.withoutLastComponent() ?? PathString.homeDirectory()?.getSubdir("Desktop") ?? PathString.homeDirectory() ?? PathString.currentDirectory()
		#endif

		guard let path = initialPath else
		{
			gLogger.error("Unable to locate path for image: \(filename)")
			return nil
		}

		// Make sure the path exists
		if !path.createDirectory()
		{
			gLogger.error("Unable to create directory (\(path)) for image write for file: \(filename)")
			return nil
		}

		guard let name = filename.lastComponent() else { return nil }
		return (path + name).toUrl()
	}

	/// Asynchronous writing of an image to a RAW file named `filename`
	///
	/// See `locateFilenameURL` for how filename is parsed/treated
	///
	/// Throws an ImageError.WriteFailure exception on most errors except the final write operation
	///
	/// All other errors are logged (as errors) but the caller is not notified as these errors occur on a DispatchQueue
	public func writeRaw(to filename: PathString, binaryHeader: Data? = nil, async: Bool = true) throws
	{
		guard let imageData = buffer.toData(count: width * height) else
		{
			throw ImageError.WriteFailure("Unable to copy image data for writing RAW image: \(filename)")
		}

		// Copy the image data with optional binary header
		var finalSize = width * height * MemoryLayout<Sample>.size
		if binaryHeader != nil { finalSize += binaryHeader!.count }
		var varData = Data(capacity: finalSize)
		if binaryHeader != nil { varData += binaryHeader! }
		varData += imageData

		// Note that once we build our data into `varData` we mjust assign it to the constant `data`. We do this due to a bug
		// in the Swift compiler (v3.0.1) related to capture promotion (https://bugs.swift.org/browse/SR-293).
		let data = varData

		guard let imageUrl = locateFilenameURL(for: filename, createPath: true) else
		{
			throw ImageError.WriteFailure("Unable to locate final path for writing RAW image: \(filename)")
		}

		if async
		{
			// Run an async process to save the image
			DispatchQueue.global(qos: .default).async
			{
				self._writeRaw(to: imageUrl, data: data)
			}
		}
		else
		{
			// No async, just write it
			_writeRaw(to: imageUrl, data: data)
		}
	}

	internal func _writeRaw(to imageUrl: URL, data: Data)
	{
		do
		{
			// Generate a final destination path
			try data.write(to: imageUrl)
			gLogger.info("Wrote RAW file: \(imageUrl.path)")
		}
		catch
		{
			gLogger.error("Failed to write RAW image (\(imageUrl)): \(error.localizedDescription)")
		}
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// PNG file support
// ---------------------------------------------------------------------------------------------------------------------------------

#if os(Linux)
extension ImageBuffer where Sample == Color
{
	/// Asynchronous writing of a Color image to a PNG file named `filename`
	///
	/// See `locateFilenameURL` for how filename is parsed/treated
	///
	/// The default behavior is to perform file IO operations asynchronously. To disable this behavior, set `async` to `false`.
	///
	/// Throws an ImageError.WriteFailure on errors related to file pathing
	///
	/// All other errors are logged (as errors) but the caller is not notified as these errors occur on a DispatchQueue
	public func writePng(to filename: PathString, numbered: Bool = false, async: Bool = true) throws
	{
		guard var imageUrl = locateFilenameURL(for: filename, createPath: true) else
		{
			throw ImageError.WriteFailure("Unable to locate final path for writing Color PNG image: \(filename)")
		}

		if numbered
		{
			guard let path = PathString(imageUrl.path).withoutLastComponent() else
			{
				throw ImageError.WriteFailure("writePng: Aborting - unable to extract path from url: \(imageUrl)")
			}

			guard let filename = PathString(imageUrl.path).lastComponent() else
			{
				throw ImageError.WriteFailure("writePng: Aborting - unable to extract path from url: \(imageUrl)")
			}

			var parts = filename.split(on: ".")
			let ext = parts.count > 1 ? parts.last! : "png"
			if parts.count > 1 { parts.removeLast() }
			let fileBase = parts.joined(separator: ".")

			// Scan the directory for *.luma files so we can add to the end of the list
			let largestFileNumber = (path.getLargestFileNumberFromDirectory(pattern: "[.]\(ext)$") ?? 0) + 1

			// Generate a filename
			imageUrl = (path + "\(largestFileNumber)-\(fileBase).\(ext)").toUrl()
		}

		var rgbSamples = UnsafeMutableArray<UInt8>(withCapacity: width * height * 3)
		for i in 0..<width * height
		{
			let argb = buffer[i]
			rgbSamples.add(UInt8((argb >> 16) & 0xff))
			rgbSamples.add(UInt8((argb >>  8) & 0xff))
			rgbSamples.add(UInt8((argb >>  0) & 0xff))
		}

		if async
		{
			// Run an async process to save the image
			DispatchQueue.global(qos: .default).async
			{
				defer { rgbSamples.free() }
				do
				{
					try self.writePngData(to: imageUrl, rgbSamples: rgbSamples)
				}
				catch
				{
					gLogger.error(error.localizedDescription)
				}
			}
		}
		else
		{
			defer { rgbSamples.free() }
			do
			{
				try writePngData(to: imageUrl, rgbSamples: rgbSamples)
			}
			catch
			{
				gLogger.error(error.localizedDescription)
				throw error
			}
		}
	}

	/// Internal implementation for writePng()
	///
	/// This function was split apart from its parent in order to allow for async/non-async operation
	private func writePngData(to imageUrl: URL, rgbSamples: UnsafeMutableArray<UInt8>) throws
	{
		guard let fp = fopen(imageUrl.path, "wb") else
		{
			throw ImageError.WriteFailure("Unable to create Color PNG file: \(imageUrl)")
		}

		defer { fclose(fp) }

		// Setup the PNG structures
		var png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, nil, nil, nil)
		if png_ptr == nil
		{
			throw ImageError.WriteFailure("Failed to create Color PNG write structure")
		}

		var info_ptr = png_create_info_struct(png_ptr)
		if info_ptr == nil
		{
			png_destroy_write_struct(&png_ptr, nil)
			throw ImageError.WriteFailure("Failed to create Color PNG info structure")
		}

		// // DEFINED AS: (*png_set_longjmp_fn(png_ptr, longjmp, sizeof(jmp_buf)))
		// if setjmp(png_jmpbuf(png_ptr))
		// {
		// 	// png_destroy_write_struct(png_ptr, info_ptr)
		// 	// fclose(fp)
		// 	throw ImageError.WriteFailure("Failed during Color PNG write")
		// }

		png_init_io(png_ptr, fp)
		png_set_IHDR(png_ptr, info_ptr, png_uint_32(self.width), png_uint_32(self.height), 8, PNG_COLOR_TYPE_RGB, PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT)
		png_set_filter(png_ptr, PNG_FILTER_TYPE_BASE, PNG_NO_FILTERS)
		png_write_info(png_ptr, info_ptr)

		// WRITE
		var rowPointers = UnsafeMutableArray<UnsafeMutablePointer<UInt8>?>(withCapacity: self.height)

		for i in 0..<self.height
		{
			rowPointers.add(rgbSamples._rawPointer.advanced(by: self.width * i * 3))
		}

		png_write_image(png_ptr, rowPointers._rawPointer)

		// Cleanup
		rowPointers.free()
		png_write_end(png_ptr, nil)
		png_destroy_write_struct(&png_ptr, &info_ptr)

		gLogger.info("Wrote Color PNG file: \(imageUrl.path)")
	}
}

extension ImageBuffer where Sample == Luma
{
	/// Asynchronous writing of a Luma image to a PNG file named `filename`
	///
	/// See `locateFilenameURL` for how filename is parsed/treated
	///
	/// The default behavior is to perform file IO operations asynchronously. To disable this behavior, set `async` to `false`.
	///
	/// Throws an ImageError.WriteFailure on errors related to file pathing
	///
	/// All other errors are logged (as errors) but the caller is not notified as these errors occur on a DispatchQueue
	public func writePng(to filename: PathString, numbered: Bool = false, async: Bool = true) throws
	{
		guard var imageUrl = locateFilenameURL(for: filename, createPath: true) else
		{
			throw ImageError.WriteFailure("Unable to locate final path for writing Luma PNG image: \(filename)")
		}

		if numbered
		{
			guard let path = PathString(imageUrl.path).withoutLastComponent() else
			{
				throw ImageError.WriteFailure("writePng: Aborting - unable to extract path from url: \(imageUrl)")
			}

			guard let filename = PathString(imageUrl.path).lastComponent() else
			{
				throw ImageError.WriteFailure("writePng: Aborting - unable to extract path from url: \(imageUrl)")
			}

			var parts = filename.split(on: ".")
			let ext = parts.count > 1 ? parts.last! : "png"
			if parts.count > 1 { parts.removeLast() }
			let fileBase = parts.joined(separator: ".")

			// Scan the directory for *.luma files so we can add to the end of the list
			let largestFileNumber = (path.getLargestFileNumberFromDirectory(pattern: "[.]\(ext)$") ?? 0) + 1

			// Generate a filename
			imageUrl = (path + "\(largestFileNumber)-\(fileBase).\(ext)").toUrl()
		}

		if async
		{
			// Run an async process to save the image
			DispatchQueue.global(qos: .default).async
			{
				do
				{
					try self.writePngData(to: imageUrl)
				}
				catch
				{
					gLogger.error(error.localizedDescription)
				}
			}
		}
		else
		{
			do
			{
				try writePngData(to: imageUrl)
			}
			catch
			{
				gLogger.error(error.localizedDescription)
				throw error
			}
		}
	}

	/// Internal implementation for writePng()
	///
	/// This function was split apart from its parent in order to allow for async/non-async operation
	private func writePngData(to imageUrl: URL) throws
	{
		guard let fp = fopen(imageUrl.path, "wb") else
		{
			throw ImageError.WriteFailure("Unable to create Color PNG file: \(imageUrl)")
		}

		defer { fclose(fp) }

		// Setup the PNG structures
		var png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, nil, nil, nil)
		if png_ptr == nil
		{
			throw ImageError.WriteFailure("Failed to create Luma PNG write structure")
		}

		var info_ptr = png_create_info_struct(png_ptr)
		if info_ptr == nil
		{
			png_destroy_write_struct(&png_ptr, nil)
			throw ImageError.WriteFailure("Failed to create Luma PNG info structure")
		}

		// // DEFINED AS: (*png_set_longjmp_fn(png_ptr, longjmp, sizeof(jmp_buf)))
		// if setjmp(png_jmpbuf(png_ptr))
		// {
		// 	// png_destroy_write_struct(png_ptr, info_ptr)
		// 	// fclose(fp)
		// 	throw ImageError.WriteFailure("Failed during Luma PNG write")
		// }

		png_init_io(png_ptr, fp)
		png_set_IHDR(png_ptr, info_ptr, png_uint_32(self.width), png_uint_32(self.height), 8, PNG_COLOR_TYPE_GRAY, PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT)
		png_set_filter(png_ptr, PNG_FILTER_TYPE_BASE, PNG_NO_FILTERS)
		png_write_info(png_ptr, info_ptr)

		// WRITE
		var rowPointers = UnsafeMutableArray<UnsafeMutablePointer<Luma>?>(withCapacity: self.height)

		for i in 0..<self.height
		{
			rowPointers.add(self.buffer.advanced(by: self.width * i))
		}

		png_write_image(png_ptr, rowPointers._rawPointer)

		// Cleanup
		rowPointers.free()
		png_write_end(png_ptr, nil)
		png_destroy_write_struct(&png_ptr, &info_ptr)

		gLogger.info("Wrote Luma PNG file: \(imageUrl.path)")
	}
}
#endif // os(Linux)

#if os(macOS)
extension ImageBuffer
{
	/// Asynchronous writing of a Color image to a PNG file named `filename`
	///
	/// See `locateFilenameURL` for how filename is parsed/treated
	///
	/// The default behavior is to perform file IO operations asynchronously. To disable this behavior, set `async` to `false`.
	///
	/// Throws an ImageError.WriteFailure on errors related to file pathing
	///
	/// All other errors are logged (as errors) but the caller is not notified as these errors occur on a DispatchQueue
	public func writePng(to filename: PathString, numbered: Bool = false, async: Bool = true) throws
	{
		guard var imageUrl = locateFilenameURL(for: filename, createPath: true) else
		{
			throw ImageError.WriteFailure("Unable to locate final path for writing PNG image: \(filename)")
		}

		if numbered
		{
			guard let path = PathString(imageUrl.path).withoutLastComponent() else
			{
				throw ImageError.WriteFailure("writePng: Aborting - unable to extract path from url: \(imageUrl)")
			}

			guard let filename = PathString(imageUrl.path).lastComponent() else
			{
				throw ImageError.WriteFailure("writePng: Aborting - unable to extract path from url: \(imageUrl)")
			}

			var parts = filename.split(on: ".")
			let ext = parts.count > 1 ? parts.last! : "png"
			if parts.count > 1 { parts.removeLast() }
			let fileBase = parts.joined(separator: ".")

			// Scan the directory for *.luma files so we can add to the end of the list
			let largestFileNumber = (path.getLargestFileNumberFromDirectory(pattern: "[.]\(ext)$") ?? 0) + 1

			// Generate a filename
			imageUrl = (path + "\(largestFileNumber)-\(fileBase).\(ext)").toUrl()
		}

		if async
		{
			// Run an async process to save the image
			DispatchQueue.global(qos: .default).async
			{
				do
				{
					try self.buffer.toNSImage(width: self.width, height: self.height)?.savePng(to: imageUrl)

					gLogger.info("Wrote PNG file: \(imageUrl.path)")
				}
				catch
				{
					gLogger.error(error.localizedDescription)
				}
			}
		}
		else
		{
			do
			{
				try self.buffer.toNSImage(width: self.width, height: self.height)?.savePng(to: imageUrl)
				gLogger.info("Wrote PNG file: \(imageUrl.path)")
			}
			catch
			{
				gLogger.error(error.localizedDescription)
				throw error
			}
		}
	}
}
#endif // os(macOS)

// ---------------------------------------------------------------------------------------------------------------------------------
// Luma file support
// ---------------------------------------------------------------------------------------------------------------------------------

extension ImageBuffer where Sample == Luma
{
	/// Read the image from a .luma file named `filename`
	///
	/// Throws:
	///		* An error thrown by initializing a Data from a file, if the Data object cannot read the file
	///		* An ImageError.FileDimensionMismatch, if the dimension of the image file and its data size do not match
	public convenience init(fromLumaFile path: PathString, userData: inout Data) throws
	{
		// Get the data
		let imageURL = path.toUrl()
		let data = try Data(contentsOf: imageURL)

		// The data offset
		var offset = data.startIndex
		let end = data.endIndex

		// Get the dimensions of our image
		let w = data.subdata(in: Range(uncheckedBounds: (offset, end))).to(type: Int16.self)
		offset += MemoryLayout.size(ofValue: w)

		let h = data.subdata(in: Range(uncheckedBounds: (offset, end))).to(type: Int16.self)
		offset += MemoryLayout.size(ofValue: h)

		// Initialize the ImageBuffer
		self.init(width: Int(w), height: Int(h))

		// Get the size of the user data
		let userDataSize = data.subdata(in: Range(uncheckedBounds: (offset, end))).to(type: Int32.self)
		offset += MemoryLayout.size(ofValue: userDataSize)
		if userDataSize > 0
		{
			userData = data.subdata(in: Range(uncheckedBounds: (offset, offset + Int(userDataSize))))
			offset += Int(userDataSize)
		}
		else
		{
			userData = Data()
		}

		// Ensure that our image data size is correct
		let imageDataSize = end - offset
		if imageDataSize != width * height
		{
			throw ImageError.FileDimensionMismatch
		}

		// Copy the image data into our buffer
		data.subdata(in: Range(uncheckedBounds: (offset, end))).copyBytes(to: buffer, count: width*height)
	}

	/// Write the image to a LUMA file with a base name of `filebase`
	///
	/// If `reserveMB` is not provided, the value `system.ReservedDiskSpaceMB` is used.
	///
	/// `withHeaderData` is used to include additional information with the LUMA file. Generally, this parameter should be `nil` in
	/// which case this method will use the current temporal state information found in the `Config` class. If `withHeaderData` is
	/// provided, this header will be used instead of the current temporal state information.
	///
	/// By default, this method will perform the disk IO operations asynchronously. To disable this, pass `false` for the `async`
	/// parameter.
	///
	/// Throws:
	///		ImageError.WriteFailure exception on file pathing errors
	///		ImageError.Conversion exception on conversion error
	///
	/// All other errors are logged (as errors) but the caller is not notified as these errors occur on a DispatchQueue
	public func writeLuma(to fileBase: String, reservedMB: Int = Config.systemReservedDiskSpaceMB, withHeaderData innerHeader: Data? = nil, async: Bool = true) throws
	{
		// Copy the image data with headers
		let innerHeaderSize = (innerHeader?.count ?? 12)
		var lumaHeader = Data(capacity: 8 + innerHeaderSize)
		lumaHeader += Int16(width)
		lumaHeader += Int16(height)
		lumaHeader += Int32(innerHeaderSize)

		// If the user provided an inner header, use that, otherwise we'll use the temporal state information from `Config`
		if let innerHeader = innerHeader
		{
			lumaHeader += innerHeader
		}
		else
		{
			lumaHeader += Int32(Config.replayTemporalState.offset.x)
			lumaHeader += Int32(Config.replayTemporalState.offset.y)
			lumaHeader += Config.replayTemporalState.angleDegrees
		}

		// On macOS -> Desktop or $HOME or getcwd()
		// Other -> $HOME or getcwd()
		let tmpPath = Config.diagnosticLumaFilePath.isEmpty ? PathString(fileBase) : (Config.diagnosticLumaFilePath + fileBase)

		guard let tmpImageUrl = locateFilenameURL(for: tmpPath, createPath: true) else
		{
			throw ImageError.WriteFailure("Unable to locate final path for writing Luma debug image: \(fileBase)")
		}

		guard let path = PathString(tmpImageUrl.path).withoutLastComponent() else
		{
			throw ImageError.WriteFailure("writeLuma: Aborting - unable to extract path from url: \(tmpImageUrl)")
		}

		// Scan the directory for *.luma files so we can add to the end of the list
		let largestFileNumber = (path.getLargestFileNumberFromDirectory(pattern: "[.]luma$") ?? 0) + 1

		// Generate a filename
		let imageUrl = (path + "\(largestFileNumber)-\(fileBase).luma").toUrl()

		// Note that once we build our data into `varData` we must assign it to the constant `data`. We do this due to a bug
		// in the Swift compiler (v3.0.1) related to capture promotion (https://bugs.swift.org/browse/SR-293).
		let data = lumaHeader

		// Do we have enough space?
		guard let freeBytes = path.availableSpaceForPath() else
		{
			throw ImageError.WriteFailure("writeLuma: Aborting - unable to determine available space to write Luma image: \(path)")
		}

		let dataBytes = UInt64(width * height + data.count)
		let finalFreeMB = freeBytes - dataBytes
		let limitBytes = UInt64(reservedMB) * 1024 * 1024

		if finalFreeMB < limitBytes
		{
			throw ImageError.WriteFailure("writeLuma: Aborting - not enough disk space to write Luma image (\(path)): free(\(freeBytes)) - data(\(dataBytes)) < \(limitBytes)")
		}

		try writeRaw(to: PathString(imageUrl.path), binaryHeader: data, async: async)
	}
}
