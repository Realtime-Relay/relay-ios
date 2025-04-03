// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Realtime",
    platforms: [
        .iOS(.v13),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Realtime",
            targets: ["Realtime"]
        ),
        .executable(
            name: "realtime-cli",
            targets: ["RealtimeCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/nats-io/nats.swift.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "Realtime",
            dependencies: [
                .product(name: "Nats", package: "nats.swift")
            ]
        ),
        .executableTarget(
            name: "RealtimeCLI",
            dependencies: ["Realtime"]
        ),
        .testTarget(
            name: "RealtimeTests",
            dependencies: ["Realtime"]
        ),
    ]
)
