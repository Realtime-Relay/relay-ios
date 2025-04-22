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
        .executable(name: "realtime-ios-cli", targets: ["realtime-ios-cli"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nats-io/nats.swift.git", from: "0.4.0"),
        .package(url: "https://github.com/nnabeyang/swift-msgpack", from: "0.7.0"),
    ],
    targets: [
        .target(
            name: "Realtime",
            dependencies: [
                .product(name: "Nats", package: "nats.swift"),
                .product(name: "JetStream", package: "nats.swift"),
                .product(name: "SwiftMsgpack", package: "swift-msgpack"),
            ]),
        .executableTarget(
            name: "realtime-ios-cli",
            dependencies: ["Realtime"]),
        .testTarget(
            name: "RealtimeTests",
            dependencies: ["Realtime"]),
    ]
)
