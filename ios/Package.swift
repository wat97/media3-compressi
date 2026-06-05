// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "vidsqueeze",
    platforms: [
        .macOS(.v13),
        .iOS(.v14),
    ],
    products: [
        .library(name: "vidsqueeze", targets: ["vidsqueeze"]),
    ],
    targets: [
        .target(
            name: "vidsqueeze",
            path: "Classes"
        ),
        .testTarget(
            name: "vidsqueezeTests",
            dependencies: ["vidsqueeze"],
            path: "Tests"
        ),
    ]
)
