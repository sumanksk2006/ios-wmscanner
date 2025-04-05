// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WMScanner",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "WMScanner",
            targets: ["WMScanner"]),
    ],
    targets: [
        .target(
            name: "WMScanner",
            path: "WMScanner/"
        ),
        .testTarget(
            name: "WMScannerTests",
            dependencies: ["WMScanner"],
            path: "WMScannerTests/"
        ),
    ]
)
