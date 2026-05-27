# Changelog

All notable changes to Keylight are documented in this file.

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
- Dashboard: "SDK Key" section with rotate-and-reveal flow.

### Migration

Existing tenants are in **legacy mode** (`sdkKeyHash: null`) and continue to accept requests with no header. The dashboard shows a one-time "Generate your SDK key" banner; once generated, the gate becomes mandatory for that tenant. Your shipped apps on 0.2.x continue to work against legacy-mode tenants — upgrade at your own pace.

## [0.2.0] - 2026-04-12

### Added
- Self-service tenant signup at `/signup` with Turnstile CAPTCHA and email verification
- Operator admin portal at `/admin` with tenants list, detail, mutations, plans, metrics, and audit log
- Stripe Billing integration: paid plan checkout, subscription lifecycle webhooks
- KV-backed tenant storage (`KVTenantResolver`) with uniqueness enforcement on email, keyPrefix, tenantId
- AES-GCM master encryption key for Ed25519 private key storage at rest
- Argon2id password hashing via `@noble/hashes` with dual-verify PBKDF2 migration
- `TenantCounterDO` Durable Object for per-tenant usage metering (licenses, instances, API calls)
- Hard instance cap enforcement at `/activate` via atomic check-and-increment
- Soft license/API metering with 90% warning emails via Resend
- 6-state tenant lifecycle machine: `pending_verification → trial → active → past_due → canceled → suspended`
- Route authorization guards (`requireOperatorSession`, `requireTenantSession`, `requireTenantAndState`)
- Structured audit log in KV with 365-day TTL and inverted-timestamp ordering
- Resend email wrapper with 5 templates (verify, warning, mint confirmation, cancellation, operator notify)
- Turnstile server-side verification for signup anti-abuse
- Dashboard usage bars with yellow (75%) and red (90%) banners
- Manual license mint from tenant dashboard
- CSV license export (Enterprise-only feature gate)
- Product management with `maxProducts` plan cap
- Reconciliation CLI script for counter drift correction
- Grace period reaper (lazy: canceled → suspended after 7 days)
- Stripe Billing customer portal integration for plan self-service

### Changed
- `makeTenantResolver()` returns composite resolver (KV-first, bundled fallback)
- `makeSecretResolver()` returns composite resolver (encrypted KV-first, Wrangler fallback)
- Session cookies include `role` field (`tenant` or `operator`)
- `verifyPassword()` dispatches on prefix (`argon2id$` or `pbkdf2$`)
- Login handler silently rehashes PBKDF2 → Argon2id on success

### Deprecated
- Static `BUNDLED_TENANTS` list (retained as migration fallback only)
- `KEYLIGHT_DASHBOARD_PASSWORD_HASH_<TENANT_ID>` Wrangler secrets (new tenants store hash in KV)

## [0.1.0] - 2026-04-10

### Added
- Multi-tenant licensing foundation
- Swift SDK with SwiftUI paywall view
- Cloudflare Worker backend with Ed25519 lease signing
- Stripe webhook license issuance
- Per-tenant dashboard with PBKDF2 auth
- LicenseDO Durable Object for serialized mutations
