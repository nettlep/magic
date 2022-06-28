//
//  Codable.swift
//  Minion
//
//  Created by Paul Nettle on 2/4/18.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

/// A combination of Decodable and Encodable
public typealias Codable = Encodable & Decodable
