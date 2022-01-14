// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LinkGesture",
    platforms: [
        .iOS(.v11),
    ],
    products: [
        .library(
            name: "LinkGesture",
            targets: ["LinkGesture"]),
    ],
    targets: [
        .target(
            name: "LinkGesture",
            dependencies: []),
        .testTarget(
            name: "LinkGestureTests",
            dependencies: ["LinkGesture"]),
    ]
)
