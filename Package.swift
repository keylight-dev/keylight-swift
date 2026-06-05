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
            url: "https://github.com/Halloweedev/keylight-binaries/releases/download/0.7.0/KeylightSDK.xcframework.zip",
            checksum: "b0c39b5b73753c028d8882da2e12f7724b62f5dc959a56faa8c939c39aa024d4"
        ),
    ]
)
