// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ExpectedCallsCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "ExpectedCallsCore", targets: ["ExpectedCallsCore"])
    ],
    targets: [
        .target(name: "ExpectedCallsCore"),
        .testTarget(name: "ExpectedCallsCoreTests", dependencies: ["ExpectedCallsCore"])
    ]
)
