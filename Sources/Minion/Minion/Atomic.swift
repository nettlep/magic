//
//  Atomic.swift
//  Minion
//
//  Created by Paul Nettle on 8/22/00.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation

// Stolen from: https://www.objc.io/blog/2018/12/18/atomic-variables
public final class Atomic<A>
{
	private let queue = DispatchQueue(label: "Atomic serial queue")
	private var value_: A

	public init(_ value: A)
	{
		self.value_ = value
	}

	public var value: A
	{
		get
		{
			return queue.sync { self.value_ }
		}
		set
		{
			return queue.sync { self.value_ = newValue }
		}
	}

	public func mutate(_ transform: (inout A) -> Void)
	{
		queue.sync { transform(&self.value_) }
	}
}

public final class AtomicFlag
{
	private let queue = DispatchQueue(label: "Atomic flag serial queue")
	private var value_: Bool

	public init(_ value: Bool = false)
	{
		self.value_ = value
	}

	public var value: Bool
	{
		get
		{
			return queue.sync { self.value_ }
		}
		set
		{
			return queue.sync { self.value_ = newValue }
		}
	}

	public func mutate(_ transform: (inout Bool) -> Void)
	{
		queue.sync { transform(&self.value_) }
	}

	public func toggle()
	{
		queue.sync { self.value_ = !self.value_ }
	}
}
