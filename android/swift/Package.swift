// swift-tools-version: 6.0
import PackageDescription

/// The Android app's native core. `CryptoClickerKit` holds every rule of the game and is shared
/// unchanged with the iPhone and Apple Watch apps. `CryptoClickerBridge` plays it the way the iOS
/// app's `GameStore` does (the clock, saving, dailies, achievements and announcements) and speaks
/// JSON. `CryptoClickerJNI` exposes that to Kotlin as `libCryptoClickerJNI.so`.
///
/// The bridge tests run on any host (`swift test` here) and on an Android emulator in CI.
let package = Package(
    name: "CryptoClickerAndroid",
    // The kit needs macOS 14 when this package is built or tested on a Mac.
    platforms: [.macOS(.v14)],
    products: [
        // The library the Android app loads.
        .library(name: "CryptoClickerJNI", type: .dynamic, targets: ["CryptoClickerJNI"]),
    ],
    dependencies: [
        .package(path: "../../CryptoClickerKit"),
    ],
    targets: [
        .target(
            name: "CryptoClickerBridge",
            dependencies: [.product(name: "CryptoClickerKit", package: "CryptoClickerKit")]
        ),
        .target(name: "CryptoClickerJNI", dependencies: ["CryptoClickerBridge"]),
        .testTarget(name: "CryptoClickerBridgeTests", dependencies: ["CryptoClickerBridge"]),
    ]
)
