// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Realtime",
    platforms: [
        .macOS(.v13),
        .iOS(.v13),
    ], 
    products: [
        .library(name: "Realtime", targets: ["Realtime"]),
        .executable(name: "realtime-cli", targets: ["RealtimeCLI"]),
        .executable(name: "realtime-ios-cli", targets: ["RealtimeIOSCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nats-io/nats.swift.git", from: "0.4.0"),
        .package(url: "https://github.com/nnabeyang/swift-msgpack", from: "0.7.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "Realtime",
            dependencies: [
                .product(name: "Nats", package: "nats.swift"),
                .product(name: "JetStream", package: "nats.swift"),
                .product(name: "SwiftMsgpack", package: "swift-msgpack"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "RealtimeCLI",
            dependencies: [
                "Realtime",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "RealtimeIOSCLI",
            dependencies: [
                "Realtime",
            ],
            path: "Sources/realtime-ios-cli"
        ),
        .testTarget(
            name: "RealtimeTests",
            dependencies: ["Realtime"],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        )
    ]
)
