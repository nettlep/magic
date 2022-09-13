// swift-tools-version:5.1

import Foundation
import PackageDescription

// For Mac M1's, we need to detect if these directories exist and if so, add them. This isn't technically necessary
// for the include path, but the linker path will complain if we include a directory that doesn't exist. This is
// just to keep the build output clean.
let kHomeBrewIncludeDir = "/opt/homebrew/include"
let kHomeBrewLibDir = "/opt/homebrew/lib"

func doesDirExist(_ dirPath: String) -> Bool {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: kHomeBrewIncludeDir, isDirectory: &isDirectory) {
        if isDirectory.boolValue {
            return true
        }
    }
    return false
}

var commonSwiftSettings: [SwiftSetting] {
    var result = [SwiftSetting]()
    result.append(.unsafeFlags(["-Ounchecked"], .when(configuration: .release)))
    if doesDirExist(kHomeBrewIncludeDir) {
        result.append(.unsafeFlags(["-I\(kHomeBrewIncludeDir)"]))
    }

    return result
}

var commonLinkerSettings: [LinkerSetting] {
    var result = [LinkerSetting]()
    result.append(.unsafeFlags(["-L/usr/local/lib"]))
    if doesDirExist(kHomeBrewLibDir) {
        result.append(.unsafeFlags(["-L\(kHomeBrewLibDir)"]))
    }

    return result
}

let commonCxxSettings: [CXXSetting] =
[
    .define("NCURSES_OPAQUE", to: "0"),
    .unsafeFlags(["-pthread", "-Wall", "-Wextra"])
]

let package = Package(
    name: "magic",
 	platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "whisper", targets: ["whisper"]),
        .executable(name: "mdscodes", targets: ["mdscodes"]),
        .library(name: "Seer", type: .dynamic, targets: ["Seer"]),
        .library(name: "Minion", type: .dynamic, targets: ["Minion"]),
        .library(name: "NativeTasks", type: .static, targets: ["NativeTasks"])
    ],
    targets: [
        .target(
            name: "whisper",
            dependencies: ["Seer", "Minion", "NativeTasks", "C_ncurses", "C_AAlib", "C_Libav"],
            path: "Sources/whisper/whisper",
            cxxSettings: commonCxxSettings,
            swiftSettings: commonSwiftSettings,
        	linkerSettings: commonLinkerSettings
        ),
        .target(
            name: "mdscodes",
            dependencies: ["Seer", "Minion", "NativeTasks"], // pdndebug - remove NativeTasks?
            path: "Sources/mdscodes/mdscodes",
            cxxSettings: commonCxxSettings,
            swiftSettings: commonSwiftSettings,
        	linkerSettings: commonLinkerSettings
        ),
        .target(
            name: "Seer",
            dependencies: ["Minion", "NativeTasks", "C_libpng"],
            path: "Sources/Seer/Seer",
            cxxSettings: commonCxxSettings,
            swiftSettings: commonSwiftSettings,
            linkerSettings: commonLinkerSettings
        ),
        .target(
            name: "Minion",
            dependencies: [],
            path: "Sources/Minion/Minion",
            cxxSettings: commonCxxSettings,
            swiftSettings: commonSwiftSettings,
            linkerSettings: commonLinkerSettings
        ),
        .target(
            name: "NativeTasks",
            dependencies: [],
            path: "Sources/NativeTasks/NativeTasks",
            cxxSettings: commonCxxSettings,
            linkerSettings: commonLinkerSettings
        ),

        .systemLibrary(name: "C_libpng", path: "Sources/Seer/SystemModules/C_libpng.build"),
        .systemLibrary(name: "C_AAlib", path: "Sources/whisper/SystemModules/C_AAlib.build"),
        .systemLibrary(name: "C_ncurses", path: "Sources/whisper/SystemModules/C_ncurses.build"),
        .systemLibrary(name: "C_Libav", path: "Sources/whisper/SystemModules/C_Libav.build")
    ],

    cxxLanguageStandard: .cxx11
)
