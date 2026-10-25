// swift-tools-version: 6.0
import PackageDescription

/// Pure game logic shared by the iPhone and Apple Watch apps.
/// No UI or platform frameworks, so `swift test` runs anywhere.
let package = Package(
    name: "CryptoClickerKit",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "CryptoClickerKit", targets: ["CryptoClickerKit"]),
    ],
    targets: [
        .target(name: "CryptoClickerKit"),
        .testTarget(name: "CryptoClickerKitTests", dependencies: ["CryptoClickerKit"]),
    ]
)
