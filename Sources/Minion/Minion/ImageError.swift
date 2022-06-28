//
//  ImageError.swift
//  Minion
//
//  Created by Paul Nettle on 3/31/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

public enum ImageError: Error
{
	case Conversion(String)
	case DimensionMismatch
	case FileDimensionMismatch
	case WriteFailure(String)
}

extension ImageError: LocalizedError
{
	public var errorDescription: String?
	{
		switch self
		{
			case .Conversion(let str):
				return "ImageError.Conversion: \(str)"
			case .DimensionMismatch:
				return "ImageError.DimensionMismatch: Mismatching image dimensions"
			case .FileDimensionMismatch:
				return "ImageError.FileDimensionMismatch: Mismatching image file dimension with file data size"
			case .WriteFailure(let str):
				return "ImageError.WriteFailure: \(str)"
		}
	}
}
