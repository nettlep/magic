//
//  VideoDecodeError.swift
//  Seer
//
//  Created by Paul Nettle on 3/31/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

enum VideoDecodeError: Error
{
	case Frame(String)
	case IO(String)
	case Stream(String)
	case Codec(String)

	var localizedDescription: String
	{
		switch self
		{
			case .Frame(let str):
				return "VideoDecodeError.Frame: \(str)"
			case .IO(let str):
				return "VideoDecodeError.IO: \(str)"
			case .Stream(let str):
				return "VideoDecodeError.Stream: \(str)"
			case .Codec(let str):
				return "VideoDecodeError.Codec: \(str)"
		}
	}
}
