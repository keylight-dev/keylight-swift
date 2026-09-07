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
            url: "https://github.com/keylight-dev/keylight-binaries/releases/download/0.12.1/KeylightSDK.xcframework.zip",
            checksum: "9a8009ac76f171d44ffa46e722a5807d0fab9ef349592a0cac1c6a6c7b48f3a3"
        ),
    ]
)
