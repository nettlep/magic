//
//  main.swift
//  MDSCodes
//
//  Created by Paul Nettle on 8/31/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import Foundation
import Minion

private var optCommand = Command.None
private var optBinaryOptimization = true
private var optShuffle = true
private var optCodeBits = -1
private var optDataBits = -1
private var optVerbose = false

enum Command: String
{
	case Matrix
	case Reversible
	case Palindrome
	case Help
	case None

	var name: String { return self.rawValue }
	var lowerName: String { return name.lowercased() }
}

private func printUsage()
{
	let programName = PathString(CommandLine.arguments[0]).lastComponent() ?? "mdscodes"

	print("Usage:")
	print("")
	print("      \(programName) matrix [global options] [matrix options] code-bits data-bits")
	print("      \(programName) reversible [global options] data-bits")
	print("      \(programName) palindrome [global options] data-bits")
	print("      \(programName) help")
	print("")
	print("  COMMANDS:")
	print("      matrix                 Uses a polynomial-based matrix approach to generate MDS codes. This does not allow for")
	print("                             generating codes that may be read in reverse. If you need codes that can be read in")
	print("                             reverse, you want a reversible code or a palindrome code.")
	print("")
	print("      reversible             Generates a reversible set of codes with a bit count equal to (2n+1) where n = data-bits,")
	print("                             and a minimum distance of 3 for a single bit of error correction. Reversible codes can be")
	print("                             read in both directions (ex: face-up cards) and also allow their directionality to be")
	print("                             determined (i.e., face-up cards can be detected as being face-up.) Note that data-bits")
	print("                             must be at least 5.")
	print("")
	print("      palindrome             Uses a parity based palindrome code. This produces a set of codes with a bit count equal")
	print("                             to (2n+1) where n = data-bits, and a minimum distance of 3 for a single bit of error")
	print("                             correction. Palindrome codes can be read in both directions (ex: face-up cards) but their")
	print("                             directionality cannot be determined (i.e., face-up cards will not be detected as being")
	print("                             face-up.)")
	print("")
	print("      help                   Yer lookin' at it")
	print("")
	print("  GLOBAL OPTIONS:")
	print("")
	print("      --no-shuffle | -ns     Disable code shuffling. Code shuffling is intended to randomize the codes in the set to")
	print("                             reduce the chances of any patterns appearing on the marked deck.")
	print("")
	print("      --verbose | -v         Enables additional output related to the generated codes.")
	print("")
	print("  MATRIX OPTIONS:")
	print("")
	print("      --no-binary-opt | -nb  Disable binary optimization on the completed code set. Binary optimization is intended to")
	print("                             balance the distribution of bits across columns so the bits printed on the deck are more")
	print("                             evenly distributed.")
	print("")
	print("  ARGUMENTS:")
	print("")
	print("      code-bits              Specifies how many bits per code (generally, 18 bits or fewer)")
	print("      data-bits              Specifies the number of bits of data assigned to each code (must be less than code-bits)")
	print("")
}

func error(_ message: String) -> Bool
{
	print("ERROR: \(message)")
	printUsage()
	return false
}

/// Processes the command line arguments, setting flags and configuration values as necessary
///
/// Returns true if parsing was successful, otherwise false. Callers should call `printUsage` on a false return unless they have
/// a valid reason for not doing so.
private func parseArguments() -> Bool
{
	var i = 1
	while i < CommandLine.arguments.count
	{
		let arg = CommandLine.arguments[i]
		i += 1

		if arg.hasPrefix("-")
		{
			switch arg
			{
				case "-ns", "--no-shuffle":
					optShuffle = false
				case "-v", "--verbose":
					optVerbose = true
				case "-nb", "--no-binary-opt":
					if case Command.Matrix = optCommand { optBinaryOptimization = false }
					else { return error("Option \(arg) is only available when using the 'matrix' command") }
				default:
					return error("Unknown option: '\(arg)'")
			}
		}
		else
		{
			switch optCommand
			{
				case .None:
					switch arg.lowercased()
					{
						case Command.Matrix.lowerName:
							optCommand = .Matrix
						case Command.Reversible.lowerName:
							optCommand = .Reversible
						case Command.Palindrome.lowerName:
							optCommand = .Palindrome
						case Command.Help.lowerName:
							optCommand = .Help
						default:
							return error("Unknown command: \(arg)")
					}
				case .Matrix:
					if optCodeBits == -1
					{
						guard let value = Int(arg) else { return error("Invalid code-bits: \(arg)") }
						if value < 1 { return error("Invalid code-bits: \(arg)") }
						optCodeBits = value
					}
					else if optDataBits == -1
					{
						guard let value = Int(arg) else { return error("Invalid data-bits: \(arg)") }
						if value < 1 { return error("Invalid data-bits: \(arg)") }
						optDataBits = value
					}
					else
					{
						return error("Unknown argument: '\(arg)'")
					}
				case .Reversible:
					if optDataBits == -1
					{
						guard let value = Int(arg) else { return error("Invalid data-bits: \(arg)") }
						if value < 1 { return error("Invalid data-bits: \(arg)") }
						optDataBits = value
					}
					else
					{
						return error("Unknown argument: '\(arg)'")
					}
				case .Palindrome:
					if optDataBits == -1
					{
						guard let value = Int(arg) else { return error("Invalid data-bits: \(arg)") }
						if value < 1 { return error("Invalid data-bits: \(arg)") }
						optDataBits = value
					}
					else
					{
						return error("Unknown argument: '\(arg)'")
					}
				case .Help:
					break
			}
		}
	}

	return true
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Run the thing
// ---------------------------------------------------------------------------------------------------------------------------------

// Disable output buffering
#if os(macOS)
setbuf(__stdoutp, nil)
#else
setbuf(stdout, nil)
#endif

if parseArguments()
{
	switch optCommand
	{
		case .Matrix:
			generateMDSCodesMatrix(codeBits: optCodeBits, dataBits: optDataBits, binaryOptimization: optBinaryOptimization, shuffle: optShuffle, verbose: optVerbose)
		case .Reversible:
			generateMDSCodesReversible(dataBits: optDataBits, shuffle: optShuffle, verbose: optVerbose)
		case .Palindrome:
			generateMDSCodesPalindrome(dataBits: optDataBits, shuffle: optShuffle, verbose: optVerbose)
		case .Help:
			printUsage()
		default:
			print("Nothing to do")
	}
}
