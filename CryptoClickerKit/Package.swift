// swift-tools-version: 6.0
import PackageDescription

// The kit's String Catalog (Resources/Localizable.xcstrings) is built where Apple's tools are:
// Xcode, and `swift build` on a Mac. On Linux, where the tests also run, the kit uses its English
// text as written (see Support/Localized.swift).
#if os(macOS)
let resources: [Resource] = [.process("Resources")]
let excluded: [String] = []
#else
let resources: [Resource] = []
let excluded = ["Resources"]
#endif

/// Pure game logic shared by the iPhone and Apple Watch apps.
/// No UI or platform frameworks, so `swift test` runs anywhere.
let package = Package(
    name: "CryptoClickerKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "CryptoClickerKit", targets: ["CryptoClickerKit"]),
    ],
    targets: [
        .target(name: "CryptoClickerKit", exclude: excluded, resources: resources),
        .testTarget(name: "CryptoClickerKitTests", dependencies: ["CryptoClickerKit"]),
    ]
)
