//
//  TextUi.swift
//  Seer
//
//  Created by Paul Nettle on 5/28/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#if os(macOS) || os(Linux)

import Foundation
import C_ncurses
import C_AAlib
import NativeTasks
import Minion

/// Construct a TextUi object
///
/// This includes the initialization of the ncurses and AAlib (ASCII-art) libraries
///
/// Failures are printed to stderr and future calls that depend on those initializations will silently fail
public class TextUi
{
	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Singleton interface
	private static var singletonInstance: TextUi?
	public static var instance: TextUi
	{
		get
		{
			if singletonInstance == nil
			{
				singletonInstance = TextUi()
			}

			return singletonInstance!
		}
		set
		{
			assert(singletonInstance != nil)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Types
	// -----------------------------------------------------------------------------------------------------------------------------

	struct Window
	{
		var window: UnsafeMutablePointer<WINDOW>?
		var frameLeft = 0
		var frameTop = 0
		var frameWidth = 0
		var frameHeight = 0

		var frameBottom: Int { return frameTop + frameHeight }
		var frameRight: Int { return frameLeft + frameWidth }
		var left: Int { return frameLeft + 1 }
		var top: Int { return frameTop + 1 }
		var width: Int { return max(0, frameWidth - 2) }
		var height: Int { return max(0, frameHeight - 2) }
		var bottom: Int { return top + height }
		var right: Int { return left + width }

		var scrolling = false
		var curPair: Int32 = 0
		var curAttr: Int32 = 0

		mutating func initFrame(x: Int, y: Int, width: Int, height: Int)
		{
			uninit()

			frameLeft = x
			frameTop = y
			frameWidth = max(0, width)
			frameHeight = max(0, height)
		    window = newwin(Int32(height), Int32(width), Int32(y), Int32(x))
		}

		mutating func initClient(x: Int, y: Int, width: Int, height: Int)
		{
			initFrame(x: x-1, y: y-1, width: width+2, height: height+2)
		}

		mutating func uninit()
		{
			if window == nil { return }
			delwin(window)
			window = nil
		}

		mutating func enableScrolling(enable: Bool = true)
		{
			if window == nil { return }
			_ = scrollok(window, enable ? true : false)
			scrolling = enable
		}

		mutating func setColor(pair: Int32)
		{
			if window == nil { return }
			curPair = pair
			_ = wattron(window, COLOR_PAIR(pair))
		}

		mutating func setAttr(attr: Int32)
		{
			if window == nil { return }
			curAttr = attr
			_ = wattron(window, attr)
		}

		mutating func setColorAttr(pair: Int32, attr: Int32)
		{
			setColor(pair: pair)
			setAttr(attr: attr)
		}

		func clear()
		{
			_ = werase(window)
		}

		mutating func resetAttrs()
		{
			if window == nil { return }
			if curPair != 0
			{
				wattroff(window, COLOR_PAIR(Int32(curPair)))
				curPair = 0
			}
			if curAttr != 0
			{
				wattroff(window, Int32(curAttr))
				curAttr = 0
			}
		}

		func out(text: String)
		{
			if window == nil { return }
			_ = waddstr(window, text)
		}

		func out(characters: UnsafePointer<Int8>)
		{
			if window == nil { return }
			_ = waddstr(window, characters)
		}

		func out(x: Int, y: Int, text: String)
		{
			if window == nil { return }
			_ = mvwaddstr(window, Int32(y+1), Int32(x+1), text)
		}

		func out(x: Int, y: Int, characters: UnsafePointer<Int8>)
		{
			if window == nil { return }
			_ = mvwaddstr(window, Int32(y+1), Int32(x+1), characters)
		}

		func out(x: Int, y: Int, text: String, len: Int)
		{
			if window == nil { return }
			_ = mvwaddnstr(window, Int32(y+1), Int32(x+1), text, Int32(len))
		}

		func out(x: Int, y: Int, characters: UnsafePointer<Int8>, len: Int)
		{
			if window == nil { return }
			_ = mvwaddnstr(window, Int32(y+1), Int32(x+1), characters, Int32(len))
		}

		func refresh()
		{
			if window == nil { return }

			if scrolling == false
			{
				box(window, 0, 0)
			}

			wrefresh(window)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// ncurses helpers - #defines from ncurses.h ported to computed properties
	// -----------------------------------------------------------------------------------------------------------------------------

	let NCURSES_ATTR_SHIFT: Int32 = 8
	func NCURSES_BITS(_ mask: Int32, _ shift: Int32) -> Int32 { return mask << (shift + NCURSES_ATTR_SHIFT) }

	var A_NORMAL: Int32     { return 0 }
	var A_ATTRIBUTES: Int32 { return NCURSES_BITS(~(1 - 1), 0) }
	var A_CHARTEXT: Int32   { return NCURSES_BITS(1, 0) - 1 }
	var A_COLOR: Int32      { return NCURSES_BITS((1 << 8) - 1, 0) }
	var A_STANDOUT: Int32   { return NCURSES_BITS(1, 8) }
	var A_UNDERLINE: Int32  { return NCURSES_BITS(1, 9) }
	var A_REVERSE: Int32    { return NCURSES_BITS(1, 10) }
	var A_BLINK: Int32      { return NCURSES_BITS(1, 11) }
	var A_DIM: Int32        { return NCURSES_BITS(1, 12) }
	var A_BOLD: Int32       { return NCURSES_BITS(1, 13) }
	var A_ALTCHARSET: Int32 { return NCURSES_BITS(1, 14) }
	var A_INVIS: Int32      { return NCURSES_BITS(1, 15) }
	var A_PROTECT: Int32    { return NCURSES_BITS(1, 16) }
	var A_HORIZONTAL: Int32 { return NCURSES_BITS(1, 17) }
	var A_LEFT: Int32       { return NCURSES_BITS(1, 18) }
	var A_LOW: Int32        { return NCURSES_BITS(1, 19) }
	var A_RIGHT: Int32      { return NCURSES_BITS(1, 20) }
	var A_TOP: Int32        { return NCURSES_BITS(1, 21) }
	var A_VERTICAL: Int32   { return NCURSES_BITS(1, 22) }
	var A_ITALIC: Int32     { return NCURSES_BITS(1, 23) }  // ncurses extension

	// -----------------------------------------------------------------------------------------------------------------------------
	// Class constants
	// -----------------------------------------------------------------------------------------------------------------------------

	/// FixedPoint scale
	private let kFixedShift: Int64 = 16

	/// Font aspect (width / height)
	///
	/// This value was gathered from a terminal using a screenshot and looking at the width/height of a 10x10 block of
	/// text. The measurement was 142x342
	private let kFontAspect: Float = 0.4152046784

	/// Luma image width ratio of screen (1.0 = full width)
	private let kLumaImageScreenWidthRatio: Float = 0.95

	/// Number of perf lines
	private let kPerfLineCount = 2

	/// Number of stat lines
	private let kStatLineCount = 9

	// -----------------------------------------------------------------------------------------------------------------------------
	// Colors & Attributes
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Colors & Attributes
	private let kPerfColor: Int32 = 2
	private let kStatColor: Int32 = 3
	private let kLogColor: Int32 = 4

	// -----------------------------------------------------------------------------------------------------------------------------
	// Data members
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Used to provide synchronized access to the entire UI
	private var ThreadMutex = PThreadMutex()

	/// (ncurses) Window representing the main screen
	private var mScreen: UnsafeMutablePointer<WINDOW>! = nil

	/// Stored size of the screen
	private var mStoredScreenSize = IVector(x: 0, y: 0)

	/// (ncurses) Window representing the luma image
	private var mLumaWin = Window()

	/// (ncurses) Window representing the performance stats
	private var mPerfWin = Window()

	/// (ncurses) Window representing the scanning stats window
	private var mStatWin = Window()

	/// (ncurses) Window representing the log window
	private var mLogWin = Window()

	/// (aaLib) ASCII-art context
	private var mAAContext: UnsafeMutablePointer<aa_context>! = nil

	/// Our current render params
	private var mAARenderParams: UnsafeMutablePointer<aa_renderparams>! = nil

	private var mAAHardwareParams = aa_hardwareparams()

	/// The width of the luma image
	private var mLumaSize = IVector(x: 1920, y: 1080)

	/// Stores the recent history of the log, so that it can be re-populated after being recreated
	public var logRecentHistory = [String]()

	/// Variable letting is know if we should resize
	public var resizeRequested = false

	// -----------------------------------------------------------------------------------------------------------------------------
	// Calculated properties
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the width of the text-representation image buffer for text display
	///
	/// If the text display could not be initialized, this function returns 0
	var aaTextScreenWidth: Int
	{
		if mAAContext == nil { return 0 }
		return Int(aa_scrwidth(mAAContext))
	}

	/// Returns the height of the text-representation image buffer for text display
	///
	/// If the text display could not be initialized, this function returns 0
	var aaTextScreenHeight: Int
	{
		if mAAContext == nil { return 0 }
		return Int(aa_scrheight(mAAContext))
	}

	/// Returns the aspect of the Luma image (width / height)
	///
	/// This value is calculated from the configured capture width/height
	var lumaWindowAspect: Float
	{
		if mLumaSize.y == 0 { return 1 }
		return Float(mLumaSize.x) / Float(mLumaSize.y)
	}

	/// Returns the width of the image pixel buffer for text display
	///
	/// If the text display could not be initialized, this function returns 0
	var aaSourceImageWidth: Int
	{
		if mAAContext == nil { return 0 }
		return Int(aa_imgwidth(mAAContext))
	}

	/// Returns the height of the image pixel buffer for text display
	///
	/// If the text display could not be initialized, this function returns 0
	var aaSourceImageHeight: Int
	{
		if mAAContext == nil { return 0 }
		return Int(aa_imgheight(mAAContext))
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Initialization
	// -----------------------------------------------------------------------------------------------------------------------------

	// Private initializer to provide a proper singleton
	private init()
	{

	}

	/// Destruct a TextUi object
	///
	/// Any initialized libraries that were not previously initialized properly will be silently ignored
	deinit
	{
		uninit()
	}

	/// Initializes the TextUi manager
	///
	/// Call this method before calling any nativeTextUi* methods
	///
	/// Be sure to call uninit() when finished to restore the display
	public func initialize(lumaSize: IVector)
	{
		mLumaSize = lumaSize
		initialize()
	}

	/// Internal initialization - do not call directly
	public func initialize()
	{
		// Uninitialize first, in case this is necessary
		uninit()

		// Init the ncurses library
	    mScreen = initscr()
		if mScreen == nil
		{
			gLogger.error("Cannot initialize libncurses")
			return
		}

		// Enable color output
		start_color()

		// Ensure a standard locale so our character output is unfiltered ASCII
		setlocale(LC_ALL, "C")
		setlocale(LC_CTYPE, "C")

		// Disable line buffering on input (i.e., get one character at a time)
		cbreak()

		// Disable delay on keyboard input (via getch())
		nodelay(mScreen, true)

		// Disable keyboard echo
		noecho()

		// Hide the cursor
		curs_set(0)

		// Don't translate return-key and CRLF handling
		nonl()

		// Don't flush the buffer on interrupt (break, SIGINT, SIGSTOP)
		intrflush(mScreen, false)

		// Translate function keys (such as arrow keys) into single-key events
		//
		// Note: This call to keypad() used to use mScreen (and not stdscr as it does now.) We use stdscr here because using
		// mScreen would cause the keypad() function to crash. The crash only happens on the ARM devices and only after switching
		// from the old Makefile builds to the Swift Build system. This does not fill me with a lot of confidence, but for now it
		// is what it is.
		keypad(stdscr, true)

		// Initialize our color pairs
		init_pair(Int16(kPerfColor), Int16(COLOR_GREEN), Int16(COLOR_BLACK))
		init_pair(Int16(kStatColor), Int16(COLOR_CYAN), Int16(COLOR_BLACK))
		init_pair(Int16(kLogColor), Int16(COLOR_YELLOW), Int16(COLOR_BLACK))

		// Store our current screen size
		let screenWidth = Int(getmaxx(mScreen))
		let screenHeight = Int(getmaxy(mScreen))
		mStoredScreenSize = IVector(x: screenWidth, y: screenHeight)

		// Create our windows
		createWindows(termSize: mStoredScreenSize)

		gLogger.info("TextUi initialized: \(mStoredScreenSize.x)x\(mStoredScreenSize.y)")
	}

	/// Uninitialize the TextUi manager and restores the display
	///
	/// Do not call any nativeTextUi* methods after this call unless you first call initialize()
	///
	/// Call this method when the TextDsiaplay manager is no longer needed
	public func uninit()
	{
		ThreadMutex.fastsync
		{
			// Wipe this out first, so we don't try doing more work while we're uninitializing
			mScreen = nil

			// Destroy our windows (including the AAlib window)
			destroyWindows()

			// End the window, restoring our terminal to something normal
			if !isendwin()
			{
			    endwin()
			}

			mStoredScreenSize = IVector(x: 0, y: 0)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Window management
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Create our windows
	private func createWindows(termSize: IVector)
	{
		//
		// Initialize our ncurses windows
		//

		// Init the Luma ASCII-art image window
		let lumaWinAspect = lumaWindowAspect / kFontAspect
		let width = Int(Float(termSize.x) * kLumaImageScreenWidthRatio)
		let height = Int(Float(width) / lumaWinAspect)
		let left = (termSize.x - width) / 2
		let top = 0
		mLumaWin.initFrame(x: left, y: top, width: width, height: height)
		mPerfWin.initClient(x: mLumaWin.left, y: mLumaWin.frameBottom + 1, width: mLumaWin.width, height: kPerfLineCount)
		mStatWin.initClient(x: mPerfWin.left, y: mPerfWin.frameBottom + 1, width: mPerfWin.width, height: kStatLineCount)
		mLogWin.initClient(x: mStatWin.left, y: mStatWin.frameBottom + 1, width: mStatWin.width, height: termSize.y - mStatWin.frameBottom - 2)

		let thisHistory = logRecentHistory
		logRecentHistory = [String]()
		for line in thisHistory
		{
			mutexedLogLine(line)
		}

		// Enable scrolling in the log window
		mLogWin.enableScrolling()

		//
		// Init the ASCII-art library
		//

		mAAHardwareParams.font = nil
		mAAHardwareParams.dimmul = 0
		mAAHardwareParams.boldmul = 0
		mAAHardwareParams.minwidth = 0
		mAAHardwareParams.minheight = 0
		mAAHardwareParams.maxwidth = 0
		mAAHardwareParams.maxheight = 0
		mAAHardwareParams.mmwidth = 0
		mAAHardwareParams.mmheight = 0
		mAAHardwareParams.width = Int32(mLumaWin.width)
		mAAHardwareParams.height = Int32(mLumaWin.height)
		mAAHardwareParams.recwidth = Int32(mLumaWin.width)
		mAAHardwareParams.recheight = Int32(mLumaWin.height)
		mAAHardwareParams.supported = AA_NORMAL_MASK

		mAAContext = aa_autoinit(&mAAHardwareParams)

		// It would be nice to log this error, but it could cause a deadlock since this method could be called within a mutex
		// and the logger will eventually call logLine() which is also mutex-guarded.
		// if mAAContext == nil
		// {
		// 	gLogger.error("Cannot initialize aaLib")
		// }

		mAARenderParams = aa_getrenderparams()!
		mAARenderParams.pointee.bright = 0
		mAARenderParams.pointee.contrast = 0
		mAARenderParams.pointee.gamma = 1
		mAARenderParams.pointee.dither = AA_NONE //AA_NONE //AA_ERRORDISTRIB //AA_FLOYD_S
		mAARenderParams.pointee.inversion = 0
		mAARenderParams.pointee.randomval = 0
	}

	/// Destroy our windows
	private func destroyWindows()
	{
		//
		// Uninit our windows
		//

		mLumaWin.uninit()
		mPerfWin.uninit()
		mStatWin.uninit()
		mLogWin.uninit()

	    //
	    // Uninit AAlib
	    //

		if mAAContext != nil
		{
			aa_close(mAAContext)
			mAAContext = nil
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Display control
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Clear the perf window
	public func clearPerf()
	{
		ThreadMutex.fastsync
		{
			mPerfWin.clear()
		}
	}

	/// Clear the stat window
	public func clearStat()
	{
		ThreadMutex.fastsync
		{
			mStatWin.clear()
		}
	}

	/// Clear the log window
	public func clearLog()
	{
		ThreadMutex.fastsync
		{
			mLogWin.clear()
		}
	}

	/// Clear the luma window
	public func clearLuma()
	{
		ThreadMutex.fastsync
		{
			mLumaWin.clear()
		}
	}

	/// Presents the image
	///
	/// All previously drawn text and/or images are presented to the display and become visible
	public func present()
	{
		if mScreen == nil { return }

		let _track_ = PerfTimer.ScopedTrack(name: "TextUi"); _track_.use()

		let oldScreenSize = mStoredScreenSize

		ThreadMutex.fastsync
		{
			if resizeRequested //|| is_term_resized(Int32(mStoredScreenSize.y), Int32(mStoredScreenSize.x))
			{
				resizeRequested = false

				endwin()
				refresh()
				clear()

				// Update our screen size
				mStoredScreenSize = IVector(x: Int(COLS), y: Int(LINES))
				if mStoredScreenSize.x == 0 || mStoredScreenSize.y == 0
				{
					mStoredScreenSize = oldScreenSize
				}

				destroyWindows()
				createWindows(termSize: mStoredScreenSize)
			}

			// First, refresh our windows
			mLumaWin.refresh()
			mPerfWin.refresh()
			mStatWin.refresh()
			mLogWin.refresh()
		}

		if oldScreenSize.x != mStoredScreenSize.x || oldScreenSize.y != mStoredScreenSize.y
		{
			gLogger.info("Terminal resized from \(oldScreenSize.x)x\(oldScreenSize.y) to \(mStoredScreenSize.x)x\(mStoredScreenSize.y)")
		}
	}

	public func updateLog()
	{
		ThreadMutex.fastsync
		{
			mLogWin.refresh()
		}
	}

	/// Resizes the display
	///
	/// This method will uninitialize and reinitializes the TextUi
	private func resizeIfNeeded()
	{
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Text output
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Draws a text string to the perf window at the given line
	///
	/// The text string is clipped to the display and does not wrap.
	///
	/// NOTE: Output to the display is not visible until present() is called.
	public func perfLine(line: Int, text: String)
	{
		if mScreen == nil { return }

		ThreadMutex.fastsync
		{
			mPerfWin.setColorAttr(pair: kPerfColor, attr: A_BOLD)
			mPerfWin.out(x: 0, y: line, text: text)
			mPerfWin.resetAttrs()
		}
	}

	/// Draws a text string to the stat window at the given line
	///
	/// The text string is clipped to the display and does not wrap.
	///
	/// NOTE: Output to the display is not visible until present() is called.
	public func statLine(line: Int, text: String)
	{
		if mScreen == nil { return }

		ThreadMutex.fastsync
		{
			mStatWin.setColorAttr(pair: kStatColor, attr: A_BOLD)
			mStatWin.out(x: 0, y: line, text: text)
			mStatWin.resetAttrs()
		}
	}

	/// Draws a text string to the stat window at the given line
	///
	/// The text string is clipped to the display and does not wrap.
	///
	/// NOTE: Output to the display is not visible until present() is called.
	public func logLine(_ text: String)
	{
		if mScreen == nil { return }

		ThreadMutex.fastsync
		{
			mutexedLogLine(text)
		}
	}

	/// This is an internal method for logging within a mutex block.
	///
	/// Draws a text string to the stat window at the given line
	///
	/// The text string is clipped to the display and does not wrap.
	///
	/// NOTE: Output to the display is not visible until present() is called.
	private func mutexedLogLine(_ text: String)
	{
		if mScreen == nil { return }

		mLogWin.setColor(pair: kLogColor)
		mLogWin.out(text: text)
		mLogWin.resetAttrs()

		logRecentHistory.append(text)
		let removeCount: Int = logRecentHistory.count - mLogWin.height
		if removeCount > 0
		{
			logRecentHistory.removeFirst(removeCount)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// ASCII-art output
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Draws a text representation of the Luma image to the text display at the given X/Y coordinates
	///
	/// NOTE: Output to the display is not visible until present() is called.
	private func draw(image: LumaBuffer)
	{
		if nil == mAAContext { return }

		// Grab the target image from the AA library, which will be used as the source for rendering to ASCII
		guard let aaSourceImage = aa_image(mAAContext) else
		{
			gLogger.error("Unable to retrieve AA image data")
			return
		}

		// Copy the image over to our source AA pixel buffer
		aaSourceImage.withMemoryRebound(to: Luma.self, capacity: aaSourceImageWidth * aaSourceImageHeight)
		{ dst in
			// Initialize a LumaBuffer from the AA buffer
			let aaLumaBuffer = LumaBuffer(width: aaSourceImageWidth, height: aaSourceImageHeight, buffer: dst)

			// Copy it over using a quick lerp
			aaLumaBuffer.resampleLerpFast(from: image)
		}

		// Render the entire ASCII-art image
		aa_render(mAAContext, mAARenderParams, 0, 0, Int32(aaTextScreenWidth), Int32(aaTextScreenHeight))

		// Get a pointer to (and dimensions of) the ASCII text screen buffer
		guard let scrBuffer = aa_text(mAAContext) else { return }

		ThreadMutex.fastsync
		{
			// Copy the ASCII text to the window
			var line = UnsafeMutableArray<Int8>(withCapacity: aaTextScreenWidth)
			scrBuffer.withMemoryRebound(to: Int8.self, capacity: aaTextScreenWidth * aaTextScreenHeight)
			{ src in
				for y in 0..<aaTextScreenHeight
				{
					line.assign(from: src.advanced(by: y * aaTextScreenWidth), count: aaTextScreenWidth)
					mLumaWin.out(x: 0, y: y, characters: line._rawPointer, len: aaTextScreenWidth)
				}
			}
		}
	}

	/// Draws a text representation of the Color image to the text display at the given X/Y coordinates
	///
	/// NOTE: Output to the display is not visible until present() is called.
	public func draw(image: DebugBuffer)
	{
		let _track_ = PerfTimer.ScopedTrack(name: "TextUi"); _track_.use()

		if let lumaBuffer = try? LumaBuffer(image)
		{
			draw(image: lumaBuffer)
		}
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Keyboard input
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Waits for a key-press and returns the key code
	public func getKey() -> Int
	{
		if mScreen == nil { return 0 }

		let key = getch()
		if key == ERR { return -1 }

		return Int(key)
	}

	// -----------------------------------------------------------------------------------------------------------------------------
	// Utilitarian
	// -----------------------------------------------------------------------------------------------------------------------------

	/// Returns the aspect of the Luma image (width / height)
	///
	/// This value is calculated from the configured capture width/height
	public func updateLumaDimensions(lumaSize: IVector)
	{
		if mLumaSize != lumaSize
		{
			mLumaSize = lumaSize
			resizeRequested = true
		}
	}

	/// Low-level clipping and drawing routine for text output to the ncurses display
	public func out(x inX: Int, y: Int, text inText: String)
	{
		var x = inX
		var text = inText
		var len = text.length()

		if mScreen == nil { return }

		// Quick tests of completely off-screen
		if y < 0 || y >= mStoredScreenSize.y || x >= mStoredScreenSize.x || x + len < 0
		{
			return
		}

		// Clip to X=0
		if x < 0
		{
			// X begins before left edge
			text = String(text[text.index(after: text.startIndex)...])
			x = 0
		}

		// Clip to X=width
		if x + len > mStoredScreenSize.x
		{
			// Trim the length
			len -= x + len - mStoredScreenSize.x
		}

		_ = ThreadMutex.fastsync
		{
			// If we get here, there is something to draw
			mvaddnstr(Int32(y), Int32(x), String(text), Int32(len))
		}
	}
}

#endif // os(macOS) || os(Linux)
