# Keylight Swift SDK

The Swift SDK for [Keylight](https://keylight.dev) — add **license keys, device
activations, and offline license validation** to macOS and iOS apps sold
outside the App Store. A completed payment on **your own Stripe account** mints
a cryptographically signed license; the SDK verifies it locally, offline, with
no server call at launch.

If you're building a paid Mac or iOS app and don't want to write a licensing
backend, this is the drop-in client. The licensing service is
[keylight.dev](https://keylight.dev).

## Why Keylight

Licensing shouldn't mean bolting a heavyweight, phone-home-or-die SDK onto your app.

- **Works offline.** The license is a signed lease your app verifies locally with Ed25519 — no
  network round-trip to gate a feature, no lockout when the machine is offline.
- **Tamper-resistant by design.** Entitlements live *inside* the signature; a forged or
  hand-edited lease can't pass verification without the tenant's private key.
- **Apple-native by design.** A focused Swift SDK for macOS and iOS, not a general REST client
  retrofitted onto Apple platforms.
- **SwiftUI-ready.** `LicenseManager` is an `ObservableObject` — gate a view on `isEntitled` with
  a plain `@EnvironmentObject` check, no bridging layer.
- **Device-bound encrypted storage by default.** License and trial state are sealed into an
  encrypted file tied to the device — no Keychain popup on first launch.

## Features

- **License keys** — signed [Ed25519 leases](https://keylight.dev/blog/ed25519-lease-format-explained), generated on payment, verified offline.
- **[Offline validation](https://keylight.dev/offline-license-validation)** — verify entitlement locally with a bundled public key; no network call to launch.
- **[Device activations](https://keylight.dev/features/device-activations)** — per-key activation limits with customer self-service deactivation.
- **[Stripe-native](https://keylight.dev/features/stripe-integration)** — payments mint licenses automatically; no webhook glue in your app.
- **[Free trials](https://keylight.dev/features/trials)** — evaluation period whose length you set in the dashboard, with clean trial-to-paid. The value you compile in is the seed a brand-new install uses before it first reaches the server.
- **Feature flags & tiers** — gate features per entitlement; supports a keyless free tier.
- **[Refund revocation](https://keylight.dev/features/refund-revocation)** — a refund or chargeback revokes the license on the next online re-check.
- **SwiftUI-ready** — `LicenseManager` is an `ObservableObject`; gate views on `isEntitled`.

## Requirements

- macOS 13+ / iOS 16+
- Swift 5.9+

## Install

Add the package in Xcode via **File → Add Package Dependencies** with URL:

`https://github.com/keylight-dev/keylight-swift.git`

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/keylight-dev/keylight-swift.git", from: "0.12.0"),
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
        trialDurationDays: 14,           // seed; the dashboard value wins once known
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

## Verifying server-owned settings

The trial length and free-tier flag your app applies come from the dashboard
(see *Free trials* above). The Keylight worker signs those settings with your
tenant key, and the SDK can refuse any that do not verify:

```swift
static let manager = try! Keylight.manager(
    // ...
    trustedPublicKeyBase64: "...",   // the key the signatures are checked against
    requireSignedConfig: true
)
```

- **Off by default.** The worker signs a product's settings only once that
  product has a trial length configured in the dashboard; every other product
  is served unsigned. Turn this on only when your product is signed — enabling
  it for an unsigned product rejects legitimate responses and pins the install
  to the `trialDurationDays` seed you compiled in.
- **Settings that do not verify are never cached.** The SDK keeps your seed
  rather than trusting what the server claimed, on every route the settings
  ride on.
- **Keys are compiled in, never fetched.** Verification is rooted in
  `trustedPublicKeyBase64` (or `trustedPublicKeys` if you build a
  `KeylightConfiguration` yourself). The SDK deliberately does not download a
  keyset at runtime: keys fetched over the same connection that serves the
  settings would let anyone able to forge one forge the other.
- **Rotation freezes, it does not break.** If you rotate to a new key id,
  builds already in the wild keep their last known settings until you ship an
  update with the new key.

This protects the network path, not the device — it stops settings being
altered in transit, not someone editing your app's binary.

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

## About Keylight

Keylight is the licensing layer for desktop apps. You keep your own Stripe account,
your own pricing, and your own customers — Keylight issues the licenses and tells your
app who is allowed to run it.

- **License keys** issued automatically when a payment completes
- **Device activations** with limits you set, and self-serve deactivation
- **Offline validation** — signed Ed25519 leases your app verifies locally
- **Feature entitlements** signed into the lease, so tiers work offline too

[keylight.dev](https://keylight.dev) · [Documentation](https://docs.keylight.dev) · [Pricing](https://keylight.dev/pricing)

### Further reading

- [How to Add License Keys to a Swift macOS App](https://keylight.dev/blog/add-license-keys-swift-macos-app)
- [License Verification at App Launch: A Swift Walkthrough](https://keylight.dev/blog/license-verification-app-launch-swift)
- [Where to Store License Data on macOS](https://keylight.dev/blog/where-to-store-license-data-macos)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.
