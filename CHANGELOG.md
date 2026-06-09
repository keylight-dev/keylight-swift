# Changelog

All notable changes to Keylight are documented in this file.

## [0.8.0] - 2026-06-07 — choose your storage backend from the factory

The one-call factory now lets you pick the storage backend directly, so the 0.6.0 storage options no longer require hand-building a `KeylightConfiguration`.

### Added

- **`storage:` parameter on `Keylight.manager(...)`** — optional, defaults to `.encryptedFile()` (the existing behavior). Pass `.encryptedFile(keychainMirror: true)` to also keep a Keychain recovery copy, or `.keychain` for the legacy Keychain-authoritative backend. It forwards straight to `KeylightConfiguration.storage`.

### Migration

- **Most apps: nothing to do.** The parameter is optional and defaults to the current behavior — omit it and nothing changes.
- If you previously hand-built a `KeylightConfiguration` *only* to set `storage`, you can drop that and pass `storage:` to the factory instead.

### Unchanged

- No wire-format, lease, or behavior changes. The default storage backend is still the device-bound encrypted file (no Keychain popup), and existing on-disk state still migrates automatically.

## [0.7.0] - 2026-06-05 — keyless funnel reporting + trial / free-tier / expired state fixes

The SDK now treats **trial**, **free tier**, and **expired** as distinct states, and reports an anonymous keyless lifecycle signal so Keylight can show a conversion funnel. Most apps update with no code changes; the two behavior changes below are fixes for free-tier-enabled products.

### Added

- **`reportKeylessState(_:)`** — an anonymous, debounced, fire-and-forget heartbeat that reports the device's keyless state (`.trial` / `.freeTier` / `.expired`). `LicenseManager` sends it automatically on state transitions to power a *trials started → converted / in free tier / expired* funnel, with conversions attributed to the prior state. You don't call it yourself.
- **`KeylessReportState`** enum (`.trial`, `.freeTier`, `.expired`).
- `LicenseProvider.reportKeylessState(_:)` — a protocol requirement with a **no-op default**, so custom providers compile unchanged.

### Changed

- **Free-tier devices are counted on launch #1.** On a product with `trialDurationDays: 0` and free tier enabled, a brand-new keyless install now resolves to `.freeTier` on the first launch. Previously it spent the first session in a degenerate `.trial(daysLeft: 0)` and only became `.freeTier` on launch #2.
- **`deactivate()` on a free-tier product now resolves to `.freeTier`** (previously `.expired`) — releasing a paid seat drops the user to the free tier they're entitled to, rather than the paywall.
- The anonymous instance ID is now generated at **trial start** (so trial devices remain attributable if they later convert). `checkTrialStatus()` stays trial-only and truthful.

### Deprecated

- **`reportFreeTier()`** — now a thin wrapper for `reportKeylessState(.freeTier)`. It still works; no action needed (it's normally invoked by the SDK, not your code).

### Migration

- **Most apps: nothing to do.** Both behavior changes are improvements and need no code change; reporting is automatic.
- Custom `LicenseProvider` conformers: `reportKeylessState(_:)` ships with a default no-op implementation — you won't get a build break. Implement it only if you wrap/proxy provider calls and want to forward the signal.

### Unchanged

- No wire-format or lease changes. `TrialStatus`'s public cases are unchanged.

## [0.6.0] - 2026-06-01 — device-bound encrypted-file storage (no Keychain popup)

License state now lives in a **device-bound encrypted file** by default, and the Keychain is left untouched — so the OS no longer shows a Keychain permission prompt on first launch. This is the new default; no code change is required to get it.

### Added

- `StorageBackend` configuration enum with two cases:
  - `.encryptedFile(keychainMirror: Bool = false)` — **new default**. The license/trial blob is sealed with a key derived from the device identity, your `tenantId`, and `productId`, and stored under Application Support. The Keychain is never read or written, so there is no first-launch popup. Pass `keychainMirror: true` to also keep a Keychain recovery copy.
  - `.keychain` — legacy behavior: the Keychain is authoritative, with the encrypted file as a crash-recovery fallback.
- `KeylightConfiguration.storage: StorageBackend` initializer parameter (defaults to `.encryptedFile()`).

### Changed

- **Default storage backend is now `.encryptedFile()`** instead of Keychain-authoritative. Existing on-disk license/trial state is migrated automatically and popup-free: on first load the SDK reads the legacy files, re-seals them into the encrypted file, and deletes the originals. Migrated installs keep their license — no re-activation.

### Migration

- **Most apps: nothing to do.** The new default removes the first-launch Keychain prompt and migrates existing on-disk state automatically.
- If you relied on license state living in the **Keychain** specifically (e.g. you read it outside the SDK, or want Keychain sync/restore), set `storage: .encryptedFile(keychainMirror: true)` to keep a Keychain copy, or `storage: .keychain` to retain the previous default.
- On platforms without Application Support (e.g. watchOS) or when a stable device ID is unavailable, the SDK transparently falls back to the Keychain — it never locks the user out.

### Unchanged

- No wire-format or server changes. Lease signing/verification and the public `LicenseManager` / provider surface are the same.

## [0.5.0] - 2026-05-29 — remove the hosted upgrade-URL helper

**Breaking.** `LicenseManager.upgradeURL(to:)` and the `makeUpgradeURL(...)` free function are removed. They built a link to Keylight's hosted upgrade page (`/p/<tenant>/upgrade/<product>`), which has been retired — customers now upgrade from the signed-in customer portal. That page already returns 404, so any in-app "Upgrade" button wired to `upgradeURL` was already failing at runtime; this release turns the dead call into a compile error so you catch it.

### Removed

- `LicenseManager.upgradeURL(to:)`
- `makeUpgradeURL(origin:tenantId:productId:licenseKey:targetKeyTypeId:)`

### Migration

- Point your in-app "Upgrade" button at the customer portal: open `https://portal.keylight.dev`. The customer signs in (magic link to the email on their license) and upgrades from their license detail — no key re-entry.
- A native in-app upgrade flow (no browser hop) is planned and will build on the existing `/upgrade-session` endpoint.

### Unchanged

- No wire-format changes. `getCachedLicenseKey()` stays on `LicenseProvider`.

## [0.4.1] - 2026-05-27 — platform list tightened

Manifest-only patch. No code or binary changes; the existing 0.4.0 xcframework is reused.

### Changed

- **`Package.swift` platforms narrowed to `macOS(.v13)` and `iOS(.v16)` only.** The previous declaration also listed `tvOS`, `watchOS`, and `visionOS` even though no slices for those platforms were ever shipped in the binary. Resolving against `0.4.0` from a tvOS/watchOS/visionOS target would link, then fail at runtime. Now SwiftPM rejects unsupported platforms at resolve time with a clear error.
- The build script's default platform list (`scripts/build-xcframework.sh`) was reduced to match.

### Coming back later

tvOS, watchOS, and visionOS support will return once the upstream build matrix is restored. No ETA.

## [0.4.0] - 2026-05-26 — defensive-readiness hardening + lifecycle event notifications

Patch against a 14-finding audit of the Swift SDK's behavior under current Worker contracts, plus a new lifecycle-event notification surface for apps that want to react to license state transitions. No wire-format changes; the factory grew three optional parameters whose defaults preserve existing behavior. **Breaking only for apps that explicitly opt into rotation** (see Migration). Apps that update without code changes get the bug fixes for free.

### Breaking (opt-in)

- **`Keylight.manager(...)` factory adds `kid:`, `freeTierEnabled:`, and `maxOfflineDays:` parameters** (all with defaults — `"k1"`, `false`, `15`).
  - `kid:` lets apps target a non-default signing key once tenant key rotation lands (0.5.0); today every tenant still uses `"k1"`, so omitting it is safe.
  - `freeTierEnabled:` must be set to `true` if your dashboard has the keyless free tier enabled — otherwise post-trial users resolve to `.expired` (hard paywall) instead of `.freeTier` (degraded analytics).
  - `maxOfflineDays:` exposes the previously-hidden 15-day offline cap; pass `nil` to disable it for air-gapped/field deployments.
- **`KeylightConfiguration.init` now precondition-asserts** that `tenantId` and `productId` match `[a-z0-9_-]+`. A malformed identifier that previously misrouted URL requests now crashes loudly at init.

### Added

- **`LicenseManager.refreshIfNeeded()` recovers from `.limited` and `.expired`.** A user whose subscription lapses (→ `.limited`) and then renews via Stripe/Polar/Gumroad webhook now recovers automatically on the next foreground or scheduled refresh — no app relaunch required. Same for `.expired` after a refund reversal.
- **`lease.status == "expired"` maps to `.expired`** (distinct from `.invalid`). The Worker's HTTP 422 hard-expiry path carries a signed `expired` lease that was previously discarded; the provider now opts 422 into body decoding so the manager can show "your license expired" rather than "your license is invalid."

### Changed

- **`checkOnLaunch()` on network failure resolves to `.limited`**, matching `performRefresh`'s offline-degraded philosophy. The prior behavior — flipping to `.invalid` — would show the paywall to a real user rebooting on an airplane. Now the user keeps running; the next refresh reconciles.
- **`LeaseVerifier.verify(...)` uses `Int(floor(...))`** explicitly, matching the Worker's `Math.floor(Date.now() / 1000)` by name. Behavior identical for positive epoch timestamps.
- **`LeaseVerifier.verify(...)` rejects leases with empty signatures** up front. The `StoreKitProvider.synthesizedLease` path produces these as a sentinel; the comment said "MUST NOT be passed to verify" but nothing enforced it.
- **`KeylightProvider.getCachedLease()` no longer pre-filters on `lease.isExpired`** before the verifier — the verifier's 300-second skew tolerance is now the single gate, eliminating spurious re-validations inside the tolerance window.
- **`KeylightProvider.hasStoredLicense()` re-verifies the lease signature** before re-populating Keychain from the file fallback. Tampered file leases are discarded rather than copied into the authoritative store.
- **`KeylightProvider.deactivateLicense()` clears `timestamp.lastSeen`** so a stale clock anchor can't cause a false-positive "clock manipulated" verdict after a long pause + re-activation.
- **`ActivateResponse.activated` and `ValidateResponse.valid` are non-optional Bool.** Both are always present on the Worker's 200 / 422 responses; making them non-optional surfaces contract drift as a loud decode error rather than a silent generic failure.
- **XOR file-obfuscation comment** now states explicitly that the key is the same in every shipped build and provides no confidentiality. Tamper resistance comes from the Ed25519 lease signature, which is re-verified on every read.

### Tests

- 13 new tests in `PatchV04Tests.swift` covering every finding ID. 120 tests total (107 existing + 13 new), 0 failures.

### Lifecycle event notifications

A new opt-in notification surface lets apps react to license state transitions — for example, dismissing a paywall when a renewal lands or showing a "thanks for renewing" message — without polling `LicenseManager.licenseState` themselves.

- **`LicenseLifecycleEvent` enum** with three cases: `.expired`, `.restored`, `.renewed`. Posted via `NotificationCenter.default` on the `keylightLifecycleEvent` notification name. The event value lives under the `lifecycleEvent` userInfo key.
- **`.expired`** fires when an active license (`.licensed` / `.trial`) transitions to a denying state (`.expired` / `.limited` / `.invalid`). **Suppressed on the very first `applyState` of a session** so cold-start paths like trial-elapsed-before-launch don't paywall users who never had a subscription. **Suppressed on `deactivate()`** — user-initiated deactivation is not an expiry signal.
- **`.restored`** fires when a denying state (`.expired` / `.limited` / `.invalid`) transitions back to `.licensed` or `.trial`. Also suppressed on first-launch.
- **`.renewed`** fires when an already-licensed user's expiry advances (new expiry > old expiry, or `Date → nil` for a lifetime upgrade). The userInfo includes `previousLicenseExpiresAt` and `newLicenseExpiresAt` (the latter omitted on lifetime upgrades). Baseline is owned by the refresh task and accumulates across runs, so back-to-back renewals don't drop the first one.
- **Stale entitlements cleared on deny.** `currentEntitlements` is now forced to `[]` on `.expired` / `.invalid` / `.freeTier`, even if the provider's cache still holds the prior lease. `.trial` continues to honor lease entitlements (paid-tier trials and beta-feature gates).
- 14 new tests in `LifecycleEventNotificationTests.swift` covering all three event types, first-launch suppression, deactivate suppression, lifetime-upgrade renewal detection, and the back-to-back race. **134/134 tests passing.**

### Migration

No code changes required for most apps — defaults preserve behavior.

If your product has the keyless free tier enabled, **you must pass `freeTierEnabled: true`** to the factory. Without it, post-trial users see the paywall instead of the free-tier experience.

### Deferred to 0.5.0

- **Multi-key trust sets** for graceful Ed25519 signing-key rotation. Today rotating the Worker's signing key would break every shipped app — there's no overlap window. 0.5.0 will add a `trustedPublicKeys: [String: String]` overload so apps can pre-load the next key alongside the current one. Requires parallel Worker work (sign-with-current, accept-old-and-new). See the PR rotation discussion for the full design.

## [0.3.1] - 2026-04-19

### Added

- Full platform xcframework via CI: tvOS, watchOS, and visionOS (device + simulator) in addition to iOS and macOS. No API changes from 0.3.0.

## [0.3.0] - 2026-04-19

### Platform support

Prebuilt xcframework covers **iOS (device + simulator) and macOS** only. Full platform matrix (tvOS, watchOS, visionOS) ships in 0.3.1 via CI.

### Breaking

- `CloudflareProvider.init(baseURL:configuration:session:)` is removed from the public API. The Worker origin is now hardcoded in the SDK. Migrate to `Keylight.manager(...)` or `CloudflareProvider(configuration:)`.
- `KeylightConfiguration` gains a required `sdkKey: String` parameter (first argument). Issue one from your Keylight dashboard and bundle it into your app.
- SwiftPM product renamed from `Keylight` to `KeylightSDK`. Consumers update `import Keylight` → `import KeylightSDK`. Factory call `Keylight.manager(...)` unchanged.

### Added

- `Keylight.manager(...)` one-call factory — build a ready `LicenseManager` without instantiating `KeylightConfiguration`, `CloudflareProvider`, or `LicenseManager` individually.
- `X-Keylight-SDK-Key` header is now attached to every Worker request and validated server-side.

### Migration

Apps running against legacy-mode tenants (no SDK key configured yet) continue to work with no `sdkKey` header; once your tenant generates one, the header becomes mandatory. Your shipped apps on 0.2.x against legacy tenants keep working — upgrade at your own pace.

## [0.1.0] - 2026-04-10

Initial public release of the Swift SDK.

- `LicenseManager` with SwiftUI integration (`EnvironmentObject` + `@StateObject`).
- `KeylightPaywallView` — drop-in paywall with activation, deactivation, and entitlement display.
- `CloudflareProvider` — HTTP transport against the Keylight Worker.
- `LeaseVerifier` — local Ed25519 signature verification for offline-tolerant validation.
- iOS and macOS support out of the box.
