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
            url: "https://github.com/Halloweedev/keylight-binaries/releases/download/0.8.0/KeylightSDK.xcframework.zip",
            checksum: "0d590208a690e7cc877b8bb80f78a9c2f51ae616538d15a43ef0316c395fa4a3"
        ),
    ]
)
