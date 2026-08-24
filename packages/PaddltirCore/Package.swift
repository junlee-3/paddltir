// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaddltirCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PaddltirCore", targets: ["PaddltirCore"]),
        .executable(name: "FixtureTool", targets: ["FixtureTool"]),
    ],
    targets: [
        .target(name: "PaddltirCore"),
        .executableTarget(name: "FixtureTool", dependencies: ["PaddltirCore"]),
        .testTarget(name: "PaddltirCoreTests", dependencies: ["PaddltirCore"]),
    ],
    swiftLanguageModes: [.v6]
)
