# Changelog

All notable changes to Keylight are documented in this file.

## [0.12.1] - 2026-09-07 — `requireSignedConfig` actually reaches the factory

A bug-fix release. 0.12.0 shipped signed-settings verification, but
`Keylight.manager(...)` could not turn it on — upgrade if you are on 0.12.0 and
want it.

### Fixed

- **`requireSignedConfig` is a parameter of `Keylight.manager(...)`.** It
  existed on `KeylightConfiguration` and was fully tested on the provider, but
  the factory — the only entry point the README shows — never exposed it, so
  the verification 0.12.0 announced was unreachable without abandoning the
  factory and hand-building the configuration, provider and manager. It is now
  a trailing parameter, defaulting to `false` as before, and pinned by a test
  that drives enforcement through the manager rather than the provider.

## [0.12.0] - 2026-09-06 — verify that your settings really came from your dashboard

One addition, off by default, and nothing to do in your app unless you want it.

### Added

- **`requireSignedConfig` — Ed25519 verification of server-owned product
  settings.** The Keylight worker has signed the trial length and free-tier
  flag on every route that delivers them since 2026-09-06. Until now nothing in
  this SDK checked those signatures. It now does, over the payload format
  shared by every Keylight SDK.

  **It is off by default, and should stay off unless you know your product is
  signed.** The worker signs a product's settings only once that product has a
  trial length configured in the dashboard; every other product is served
  unsigned. Turning this on for one of those would reject legitimate responses
  and pin the install to the seed you compiled in.

  When it is on, settings that do not verify are **never cached** — the SDK
  keeps your seed value rather than trusting what the server claimed. The check
  lives at the single point where settings are merged, so no route can be used
  to write settings around it: `/config`, `validate`, and the keyless beacon all
  pass through it.

  Verification is rooted in the `trustedPublicKeys` you compile into your app.
  The SDK does not fetch a keyset at runtime, on purpose: keys fetched over the
  same connection that serves the settings would let anyone able to forge one
  forge the other. The trade-off is that if you rotate to a new key id, builds
  already in the wild keep their last known settings until you ship an update —
  they freeze, they do not break.

  What this protects is the network path, not the device. Someone editing your
  app's binary can still do as they like; this stops settings being altered in
  transit.

## [0.11.1] - 2026-09-06 — the dashboard trial length actually reaches your app

A bug-fix release. 0.11.0 shipped the server-owned trial length, but
`LicenseManager` could not reach it — upgrade if you are on 0.11.0.

### Fixed

- **`fetchConfig()`, `effectiveTrialDurationDays()` and
  `effectiveFreeTierEnabled()` are reachable from `LicenseManager`.** They
  existed on the provider and were fully tested there, but `LicenseManager`
  never forwarded them, so `manager.fetchConfig()` did not compile and the
  server-owned values 0.11.0 announced were unreachable through the type
  almost every app actually holds. The forwarding methods are now present and
  tested against the manager, not the provider.
- **A server value of `0` survives the forward as `0`.** Not re-read as
  "unset, use the compiled-in seed" — "trials off" is the setting most likely
  to be lost to a one-line delegation, and it is now pinned by a test.

## [0.11.0] - 2026-09-05 — your dashboard trial length now reaches the app

One behavior change, and nothing to do in your app unless you want it.

### Added

- **Trial length and the free tier are settings the server owns.** Until now the
  value you passed to `KeylightConfiguration` was the only one that ever
  applied — you could set a trial length in the dashboard and nothing happened
  to your app. The SDK now resolves **server value → your configured value →
  0**, via `effectiveTrialDurationDays()` and `effectiveFreeTierEnabled()`.
- **Your configured value is still there, and still matters.** It is the *seed*:
  what a brand-new install uses before it has ever reached the server. Keep
  setting it — removing it would make first launch depend on the network.
- **No new network calls at launch.** The settings ride on `validate` (every
  licensed install) and the keyless beacon (every unlicensed one), both calls
  the SDK already makes. `fetchConfig()` is available if you want an explicit
  refresh — from a settings pane, say — but nothing calls it for you.
- **`sdk_trial_duration_days`** on activate and validate: the length your build
  was compiled with, so a 30-day build running against a 14-day dashboard
  setting shows up as a mismatch instead of a week of support tickets.

### Fixed

- **A trial enabled later now works.** The trial clock is stamped on first
  launch even when no trial is on offer yet, so if you turn trials on in the
  dashboard afterwards, existing installs have a start date to measure from.
  The stamp grants nothing by itself — status still reports no trial until a
  duration arrives.

  Read the consequence before you switch trials on for a shipped app: the
  window is measured from that original stamp, not from the day you enabled
  it. An install older than the length you set gets a trial that has *already
  expired* — turning on a 14-day trial hands nothing to anyone who installed
  more than 14 days ago. This is the same property as "an old trial is not
  restarted" below, seen from the other side, and it is deliberate. If you
  want existing installs to get a fresh window, set a length that covers
  their age.
- **Turning trials off in the dashboard sticks.** A server value of `0` means
  "trials off" and survives a relaunch, rather than being mistaken for "no
  setting" and falling back to your compiled-in value.
- **An old trial is not restarted.** Enabling a trial 60 days after an install
  does not hand that install a fresh window, so it cannot be farmed by
  reinstalling.

### Notes

- Nothing changes until you set a trial length in the dashboard. Apps whose
  tenant has never touched the setting keep using their compiled-in value
  exactly as before.

## [0.10.0] - 2026-09-04 — a keyless device no longer goes quiet while your app runs

One behavior change, on by default, with nothing to do in your app.

### Added

- **`LicenseManager` now re-reports keyless devices on a heartbeat.** The
  anonymous beacon that tells your dashboard a trial or free-tier device is
  alive used to fire only from a state transition, which for keyless states
  means only `checkOnLaunch()`. That is once per *process launch* — so an app
  that stays open (a menu-bar app, anything a customer leaves running for days)
  reported itself once and then went silent for as long as it ran. In the
  dashboard those devices show a **"last seen" frozen at "first seen"**, and an
  app version frozen at whatever shipped the day they installed.

  The manager now keeps a timer while the device is keyless. It stops on
  `.licensed`/`.limited` — a paid device reports liveness through `validate()`
  instead — and resumes on its own if the license lapses.

  Default cadence is 6 hours, and the beacon keeps its 24h debounce, so a
  resident app sends **at most one extra request per day**. Nothing on the wire
  changed.

  Opt out, or pick your own cadence, at construction:

  ```swift
  // Default — no code change needed.
  let manager = LicenseManager(provider: provider)

  // Or drive the beacon yourself.
  let manager = LicenseManager(provider: provider, keylessHeartbeatInterval: nil)
  ```

  `LicenseManager.defaultKeylessHeartbeatInterval` is the 6-hour default, should
  you want to reference it.

### Changed

- `KeylightProvider.sdkVersion` is now `"0.10.0"`.

## [0.9.0] - 2026-08-11

### Added
- `LicenseManager.refreshAfterUpgrade(timeout:pollInterval:)` — call it when the
  customer returns from completing an upgrade so new entitlements unlock in the
  running app within seconds, without waiting for the normal refresh cadence. It
  polls briefly to cover payment-webhook lag and stops as soon as the tier changes.

### Changed
- Integration guide now documents wiring `activeRevalidate()` to scene-phase
  `.active` so a revoked or expired license is caught the moment the app is
  brought forward.

## [0.8.6] - 2026-08-07

Activate, validate, and the keyless beacon send up to five extra optional
fields describing the device. Nothing to change in your app, and no API
surface moved.

### Added

- **`os_version` is sent alongside `platform`.** The numeric dotted OS version
  (`"15.5"`, `"15.5.1"`) from `ProcessInfo`, so the platform breakdown can
  distinguish OS releases, not just OS families.
- **`arch` reports the CPU architecture** the SDK was built for — `arm64` or
  `x86_64`; anything else is omitted rather than guessed.
- **`device_class` distinguishes iPhone from iPad, on iOS only.** iOS is the
  one platform where the OS name alone can't tell the hardware apart. On every
  other platform the field is omitted entirely.
- **`cpu_cores` and `memory` report the rough hardware shape as a bucket**, not
  a raw value — `"1-2"`, `"3-4"`, `"5-8"`, `"9-16"`, `"17+"` for cores, and
  `"<4GB"`, `"4-8GB"`, `"8-16GB"`, `"16-32GB"`, `"32-64GB"`, `"64GB+"` for
  memory. The SDK reads `ProcessInfo` locally and sends only the label: the
  exact core count and RAM size never leave the device, so nothing here can be
  used to fingerprint one of your customers.

All five fields are optional on the wire — apps built against older SDK
versions keep working unchanged.

## [0.8.5] - 2026-08-01 — the SDK now says which SDK it is

Activate and validate send one extra field, `sdk`. Nothing to change in your
app, and no API surface moved.

### Added

- **`sdk` is sent alongside `platform`.** `platform` reports the operating
  system (`macOS`, `iOS`, `watchOS`, `tvOS`, `visionOS`) and was previously the
  only way to tell which Keylight SDK a device ran — it worked for Swift only
  because the Apple platform names happen to be unique. That was a coincidence,
  not a contract, so the SDK now states its identity outright.

## [0.8.4] - 2026-07-29 — a revocation the client can't parse is no longer ignored

A single reliability fix, on the path that matters most: a license you revoke
from the dashboard now stops working even when the rejection arrives in a shape
the client can't read. Automatic — no API changes.

### Fixed

- **A definitive rejection whose body doesn't decode now denies.** When a
  validation was rejected, `validateLicense()` surfaced only
  `KeylightError.clientError`; any other decoding failure escaped as an untyped
  error, which the manager treats as a network blip and responds to by keeping
  the current state. A server rejection the client couldn't parse was therefore
  indistinguishable from being offline, and the license stayed active. Any
  rejection the server states definitively now denies, whether or not its body
  can be read.

  A genuine transport failure (timeout, offline, 5xx) still preserves
  last-known-good state, bounded as always by `maxOfflineDays` — a network blip
  must never downgrade a live session.

### Changed

- `KeylightProvider.sdkVersion` is now `"0.8.4"`.

## [0.8.3] - 2026-07-17 — unified device identity + refresh reliability

*Backfilled: 0.8.3 shipped without a changelog entry.*

### Added

- `machine_hash` is now attached to activate and validate, matching the keyless
  beacon. A device that converts from free tier to paid counts as one device in
  your dashboard rather than two. Only the one-way hash is transmitted, never the
  raw identifier, and the derivation stays byte-for-byte identical to the Rust
  and JS SDKs.

### Fixed

- **A long-unused install no longer expires itself.** Only backward clock
  movement beyond tolerance counts as clock manipulation. A large *forward* gap —
  the normal signature of an app that hasn't been opened in months — was treated
  as tampering and could falsely expire a valid license.
- **The lease refresh scheduler re-arms itself.** It could stop silently after a
  refresh, leaving a long-running app without scheduled revalidation until
  relaunch. It now loops.
- **The keyless beacon's 24-hour debounce is recorded only on success (HTTP
  200).** A failed beacon previously consumed the window, so one failure could
  suppress free-tier reporting for a full day.

### Changed

- `KeylightProvider.sdkVersion` is now `"0.8.3"`.

## [0.8.2] - 2026-07-09 — privacy-safe machine identity for free-tier analytics

The anonymous keyless/free-tier beacon now reports a one-way machine hash, so
your Keylight dashboard counts one device per physical machine instead of one
per install — reinstalling your app on the same Mac (or iPhone/iPad) updates the
same free-tier row instead of creating a duplicate. Automatic; the raw device
identifier never leaves the device, and there are no API changes.

### Added

- The keyless beacon now sends a `machine_hash`: a SHA-256 of a platform-stable
  device identifier (`IOPlatformUUID` on macOS, `identifierForVendor` on
  iOS/tvOS/watchOS/visionOS), namespaced to your tenant and product. Only the
  hash is transmitted — never the raw identifier. When no stable identifier is
  available the field is omitted and the SDK keeps using its per-install id.
  The derivation is byte-for-byte identical to the Rust and JS SDKs.

### Changed

- `KeylightProvider.sdkVersion` is now `"0.8.2"`.

## [0.8.1] - 2026-06-10 — version telemetry (app, SDK, platform)

The SDK now attaches lightweight, anonymous version telemetry to its network
calls, so your Keylight dashboard can break activations and validations down by
app version, SDK version, and platform. Automatic — no API changes and nothing
to call.

### Added

- The SDK now sends three optional fields on `activate`, `validate`, and the
  anonymous keyless beacon:
  - `app_version` — your app's `CFBundleShortVersionString` (when available)
  - `sdk_version` — the Keylight SDK version
  - `platform` — `macOS`, `iOS`, `watchOS`, `tvOS`, or `visionOS`
- `KeylightProvider.sdkVersion` — the current SDK version string constant.

### Migration

- Nothing to do. The fields are added automatically; no source changes, and no
  wire-format or lease changes.

### Unchanged

- No behavior, lease, or public-API changes beyond the added request fields.

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
