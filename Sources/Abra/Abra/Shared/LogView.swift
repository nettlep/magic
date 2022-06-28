//
//  LogView.swift
//  Abra
//
//  Created by Paul Nettle on 10/5/21.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

import SwiftUI
#if os(iOS)
import MinionIOS
#else
import Minion
#endif

extension LogLevel {
	var color: Color {
		switch self {
		case .Error, .Severe, .Fatal: return .brightRed
		case .Warn, .BadReport, .BadResolve, .Incorrect: return .yellow
		case .Always, .Video: return .green
		case .Debug: return .mediumGray
		case .Trace, .Status, .Frame: return .purple
		case .Result: return .white
		case .Perf: return .brightBlue
		case .Correct: return .brightGreen
		case .Resolve, .Search, .Decode: return .yellow
		case .Network: return .brightBlue
		default: return .lightGray
		}
	}
}

struct ClearLogButton: View {
	var body: some View {
		Image(systemName: "trash.fill")
			.resizable()
			.modifier(bounceActionButton(label: EmptyView(), action: {
				AbraLogDevice.logData.clear()
			}))
	}
}

struct AutoScrollButton: View {
	@Binding var autoScroll: Bool
	var scrollProxy: ScrollViewProxy
	var scrollTo: Int

	var body: some View {
		Image(systemName: "arrow.down.to.line.compact")
			.resizable()
			.modifier(bounceActionButton(label: EmptyView(), highlighted: autoScroll, action: {
				autoScroll.toggle()
				// If we just enabled autoScroll, then scroll immediately to the position specified
				if autoScroll {
					scrollProxy.scrollTo(scrollTo, anchor: .bottomLeading)
				}
			}))
	}
}

struct LogView: View {
	@ObservedObject var data: LogData
	@State var autoScroll = true

	var body: some View {
		GeometryReader { geo in
			ScrollViewReader { value in
				VStack {
					ScrollView([.horizontal, .vertical]) {
						LazyVStack(alignment: .leading) {
							ForEach(0..<data.lines.count, id: \.self) { index in
								LogLineView(logLine: data.lines[index])
									.id(index)
							}
							.environment(\.defaultMinListRowHeight, 1)
						}

						// We add an invisible line here, which represents the longest line
						// of text in the log data, allowing the ScrollView to properly size itself
						// horizontally. We also set the hight of this view to the height the parent
						// in order to ensure that there is a full view's height of blank space after
						// the log so that it isn't centered in the ScrollView.
						HStack {
						   Text(data.longestLine)
							   .fixedSize()
							   .font(.system(size: 12, design: .monospaced).italic())
							   .lineLimit(1)
							   .foregroundColor(.clear)
						}
						.frame(minHeight: geo.size.height)
					} // ScrollView
					.onChange(of: data.lines.count) { count in
						if autoScroll {
							value.scrollTo(data.lines.count - 1, anchor: .bottomLeading)
						}
					}
					.onAppear {
						if autoScroll {
							value.scrollTo(data.lines.count - 1, anchor: .bottomLeading)
						}
					}
				} // VStack
				.clipped()
				#if os(iOS)
				.onAppear { UITableView.appearance().backgroundColor = .clear }
				.onDisappear { UITableView.appearance().backgroundColor = UIColor.systemBackground }
				#endif
				.background(Color.darkGray)
				.cornerRadius(8)
				.coordinateSpace(name: "scroll")

				HStack {
					Spacer()
					ClearLogButton()
					AutoScrollButton(autoScroll: $autoScroll, scrollProxy: value, scrollTo: data.lines.count - 1)
				}
			} // ScrollViewReader
			.padding()
			#if os(iOS)
			.navigationBarTitle("Log", displayMode: .inline)
			#endif
		} // GeometryReader
	} // body: some View
}

struct LogView_Previews: PreviewProvider {
	static var testLogData: LogData {
		let data = LogData()
		data.addLine(date: "2021/01/01@09:09:09", level: .Error, text: ">>> Session starting")
		data.addLine(date: "2021/01/01@09:09:09", level: .Warn, text: ">>> VCS revisions:")
		data.addLine(date: "2021/01/01@09:09:09", level: .Info, text: ">>>    Abra:    1234@master:m")
		data.addLine(date: "2021/01/01@09:09:09", level: .Always, text: ">>>    Seer:    1234@master:m")
		data.addLine(date: "2021/01/01@09:09:09", level: .Info, text: ">>>    Minion:  1234@master:m")
		data.addLine(date: "2021/01/01@09:09:09", level: .Incorrect, text: "This is very very long very very long very very long very very long very very long very very long very very long very very long very very long very very long very very long very very long test log line")

		for i in 0..<10 {
			data.addLine(date: "2021/01/01@09:09:09", level: .Always, text: "This is a test log line #\(i)")
		}
		return data
	}

	static var previews: some View {
		LogView(data: testLogData)
		LogView(data: testLogData)
			.preferredColorScheme(.dark)
	}
}

struct LogLineView: View {
	var logLine: LogLine

	var body: some View {
		HStack {
			Text("\(logLine.date)")
				.fixedSize()
				.font(.system(size: 8, design: .monospaced))
				.lineLimit(1)
				.foregroundColor(.mediumGray)
				#if os(iOS)
				.listRowSeparator(.hidden)
				#endif
				.listRowBackground(Color.clear)
				.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
			Text("\(logLine.level.description)")
				.fixedSize()
				.font(.system(size: 8, design: .monospaced))
				.lineLimit(1)
				.foregroundColor(logLine.level.color)
				#if os(iOS)
				.listRowSeparator(.hidden)
				#endif
				.listRowBackground(Color.clear)
				.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
			Text("\(logLine.text)")
				.fixedSize()
				.font(.system(size: 10, design: .monospaced))
				.lineLimit(1)
				.foregroundColor(logLine.level.color)
				#if os(iOS)
				.listRowSeparator(.hidden)
				#endif
				.listRowBackground(Color.clear)
				.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
		}
	}
}
