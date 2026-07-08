// swift-tools-version: 6.2
// legibility:description: A Swift CLI tool that extracts structured facts from developer projects and generates AI-powered narrative case-study portfolios with SVG infographics.
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ProjectShowcase",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "showcase", targets: ["ShowcaseCLI"]),
        .library(name: "ProjectShowcase", targets: ["ProjectShowcase"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3")
    ],
    targets: [
        .target(
            name: "ProjectShowcase",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "ShowcaseCLI",
            dependencies: [
                "ProjectShowcase",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ProjectShowcaseTests",
            dependencies: ["ProjectShowcase"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
