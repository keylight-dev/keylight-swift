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
            url: "https://github.com/Halloweedev/keylight-binaries/releases/download/0.6.0/KeylightSDK.xcframework.zip",
            checksum: "e2aa3ba8228e96198bfee21e4acd928ca11cc0c83c21a764d376d44392a8a36c"
        ),
    ]
)
