// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Sequence",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Sequence",
            targets: ["Sequence"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Sequence",
            dependencies: [],
            resources: [
                // Font resources will be bundled here
                .copy("Resources/Fonts")
            ]),
        .testTarget(
            name: "SequenceTests",
            dependencies: ["Sequence"]),
    ]
)

