// swift-tools-version: 6.0
import PackageDescription

// Test the shared source compiled into the app and filter without signing or SMS.
let package = Package(
    name: "SiftCore",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SiftCore", path: "Shared", exclude: ["PrivacyInfo.xcprivacy"]),
        .testTarget(name: "SiftCoreTests", dependencies: ["SiftCore"], path: "Tests")
    ],
    swiftLanguageModes: [.v5]
)
