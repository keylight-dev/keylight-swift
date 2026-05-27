# Keylight Swift SDK

Drop-in SwiftUI licensing for macOS and iOS apps. Backed by the Keylight licensing service.

## Install

Add the package in Xcode via **File → Add Package Dependencies** with URL:

`https://github.com/Halloweedev/keylight-swift.git`

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Halloweedev/keylight-swift.git", from: "0.4.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "KeylightSDK", package: "keylight-swift"),
        ]
    ),
],
```

## Quickstart

See the full integration guide at [docs.keylight.dev/swift-sdk/install](https://docs.keylight.dev/swift-sdk/install/).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.

