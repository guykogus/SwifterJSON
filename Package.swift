// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "SwifterJSON",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .macCatalyst(.v15),
        .tvOS(.v15),
        .visionOS(.v1),
        .watchOS(.v9)
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
