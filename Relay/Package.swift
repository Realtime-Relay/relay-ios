// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Relay",
    platforms: [
        .iOS(.v13),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Relay",
            targets: ["Relay"]
        ),
        .executable(
            name: "relay-ios-cli",
            targets: ["relay-ios-cli"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/nats-io/nats.swift.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "Relay",
            dependencies: [.product(name: "Nats", package: "nats.swift")]
        ),
        .executableTarget(
            name: "relay-ios-cli",
            dependencies: ["Relay"]
        ),
        .testTarget(
            name: "RelayTests",
            dependencies: ["Relay"]
        ),
    ]
)
