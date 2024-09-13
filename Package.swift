// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "SwifterJSON",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_13),
        .tvOS(.v12),
        .visionOS(.v1),
        .watchOS(.v4),
    ],
    products: [
        .library(
            name: "SwifterJSON",
            targets: ["SwifterJSON"]
        ),
    ],
    targets: [
        .target(
            name: "SwifterJSON"
        ),
        .testTarget(
            name: "SwifterJSONTests",
            dependencies: ["SwifterJSON"]
        ),
    ]
)
