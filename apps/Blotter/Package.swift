// swift-tools-version: 6.0
import PackageDescription

// Test the shared source compiled into the app and filter without signing or SMS.
let package = Package(
    name: "BlotterCore",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BlotterCore", path: "Shared", exclude: ["PrivacyInfo.xcprivacy"]),
        .testTarget(name: "BlotterCoreTests", dependencies: ["BlotterCore"], path: "Tests")
    ],
    swiftLanguageModes: [.v5]
)
