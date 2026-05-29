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
            url: "https://github.com/Halloweedev/keylight-binaries/releases/download/0.5.0/KeylightSDK.xcframework.zip",
            checksum: "522a54ddf4b1aaf9fff19b48828b4bbc3cb36fa0ee053839d903445ae02da34d"
        ),
    ]
)
