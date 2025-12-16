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
            dependencies: []),
        .testTarget(
            name: "SequenceTests",
            dependencies: ["Sequence"]),
    ]
)

