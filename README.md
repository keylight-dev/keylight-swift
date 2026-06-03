# Keylight Swift SDK

The Swift SDK for [Keylight](https://keylight.dev) — add **license keys, device
activations, and offline license validation** to macOS and iOS apps sold
outside the App Store. A completed payment on **your own Stripe account** mints
a cryptographically signed license; the SDK verifies it locally, offline, with
no server call at launch.

If you're building a paid Mac or iOS app and don't want to write a licensing
backend, this is the drop-in client. The licensing service is
[keylight.dev](https://keylight.dev).

## Features

- **License keys** — signed [Ed25519 leases](https://keylight.dev/blog/ed25519-lease-format-explained), generated on payment, verified offline.
- **[Offline validation](https://keylight.dev/offline-license-validation)** — verify entitlement locally with a bundled public key; no network call to launch.
- **[Device activations](https://keylight.dev/features/device-activations)** — per-key activation limits with customer self-service deactivation.
- **[Stripe-native](https://keylight.dev/features/stripe-integration)** — payments mint licenses automatically; no webhook glue in your app.
- **[Free trials](https://keylight.dev/features/trials)** — a fixed-length evaluation managed by the SDK, with clean trial-to-paid.
- **Feature flags & tiers** — gate features per entitlement; supports a keyless free tier.
- **[Refund revocation](https://keylight.dev/features/refund-revocation)** — a refund or chargeback revokes the license on the next online re-check.
- **SwiftUI-ready** — `LicenseManager` is an `ObservableObject`; gate views on `isEntitled`.

## Requirements

- macOS 13+ / iOS 16+
- Swift 5.9+

## Install

Add the package in Xcode via **File → Add Package Dependencies** with URL:

`https://github.com/Halloweedev/keylight-swift.git`

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Halloweedev/keylight-swift.git", from: "0.6.0"),
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

Build a `LicenseManager` once with a single call, then gate your app on
`isEntitled`:

```swift
import KeylightSDK

@MainActor
enum Licensing {
    static let manager = try! Keylight.manager(
        sdkKey: "sdk_live_...",
        tenantId: "acme",
        productId: "widget",
        keyPrefix: "ACME",
        trustedPublicKeyBase64: "...",   // your tenant public key
        trialDurationDays: 14,
        branding: .init(
            appName: "Widget",
            purchaseURL: URL(string: "https://acme.example.com/buy")!,
            supportEmail: "support@acme.example.com",
            tintColor: .orange
        )
    )
}
```

```swift
import SwiftUI
import KeylightSDK

@main
struct WidgetApp: App {
    @StateObject private var license = Licensing.manager

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(license)
                .task { await license.checkOnLaunch() }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var license: LicenseManager

    var body: some View {
        if license.isEntitled {
            AppContent()
        } else {
            LicensePromptView()   // built-in activation UI
        }
    }
}
```

Activate a key, check a feature, or deactivate a device:

```swift
await license.activate(key: "ACME-XXXX-XXXX-XXXX")
let canExport = license.hasEntitlement("pro-export")
await license.deactivate()
```

Full integration guide: [docs.keylight.dev/swift-sdk/install](https://docs.keylight.dev/swift-sdk/install/).

## How it compares

Keylight is **Apple-native by design** — a focused Swift SDK with offline
Ed25519 leases and Stripe-native minting, rather than a general cross-platform
REST API. See [Keylight vs Keygen](https://keylight.dev/keygen-alternative),
[vs Keyforge](https://keylight.dev/keyforge-alternative), and the
[Paddle alternative](https://keylight.dev/paddle-alternative) writeups for when
each fits.

## Links

- Website: [keylight.dev](https://keylight.dev)
- Documentation: [docs.keylight.dev](https://docs.keylight.dev)
- Pricing: [keylight.dev/pricing](https://keylight.dev/pricing)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.
