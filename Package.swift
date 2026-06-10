// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Keylight",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "KeylightSDK",
            targets: ["KeylightSDK"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "KeylightSDK",
<<<<<<< HEAD
            url: "https://github.com/keylight-dev/keylight-binaries/releases/download/0.8.1/KeylightSDK.xcframework.zip",
            checksum: "cb315b0f4991547cb0ef69d8bb38b2ece09a15044021beee63a1d244d91592ba"
        ),
    ]
)
