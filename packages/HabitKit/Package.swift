// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HabitKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "HabitKit", targets: ["HabitKit"])],
    targets: [
        .target(name: "HabitKit"),
        .testTarget(name: "HabitKitTests", dependencies: ["HabitKit"])
    ]
)
