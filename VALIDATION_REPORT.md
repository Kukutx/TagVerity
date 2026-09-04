# TagVerity validation report

Validation date: 2026-09-05  
App version: 1.0.0+1

## Current validation baseline

TagVerity is a public, privacy-first, read-only NFC Inspector / Tag Checker / Batch Scanner.

The project baseline is:

- Flutter **3.47.1**
- Dart **3.13.1**
- Android application ID: `dev.kukutx.tagverity`
- Android minSdk: 24
- Android targetSdk / compileSdk: 36
- iOS minimum: 13.0
- One Flutter SDK only; this project does not require FVM or a second SDK.

GitHub Actions is the authoritative software merge gate. The workflow requires:

- dependency resolution;
- Dart formatting;
- JSON export schema validation, including schema/model version consistency;
- `flutter analyze`;
- the complete Flutter test suite;
- Android debug APK compilation;
- unsigned iOS debug compilation on macOS.

A green CI run does not replace physical NFC hardware testing.

## Core behavior covered by code and automated tests

- Single-tag NFC inspection and availability/error handling.
- Scan start, stop, timeout/error recovery, and lifecycle-safe cancellation.
- Conservative NFC tag classification without claiming proprietary application identity.
- Comparable-ID vs session-only identity semantics.
- Duplicate/repeated-ID checks only when the platform exposes an identifier that can be compared.
- Explicit NDEF support, read status, capacity, writable/read-only state, and empty-container handling.
- NDEF Text and URI decoding, UTF-8/UTF-16 handling, malformed payload handling, unknown URI prefixes, binary payload safety, and bounded summaries.
- PASS / LIMITED / REVIEW assessment.
- Manual Batch and continuous Batch scanning.
- Continuous Batch stop conditions for user stop, errors/timeouts, batch finish, app lifecycle changes, and capacity limit.
- PASS / LIMITED / REVIEW batch totals plus comparable/session-only identity totals.
- Identity-aware batch CSV output.
- Searchable local history.
- Privacy-minimized history defaults and privacy-safe migration of legacy history.
- Transactional history deletion/scrubbing: UI state changes only after persistence succeeds.
- JSON export schema **v3** and native Android/iOS report sharing with failure reporting.
- Privacy-safe diagnostics.

## Platform validation

Android and iOS project files, NFC permissions/entitlements, branding, and native share bridges are committed.

CI can verify Android compilation and an unsigned iOS build. It cannot verify NFC antenna behavior, OS NFC session UX, device-specific tag support, Apple signing, or store submission.

The physical-device acceptance matrix is tracked as the `v1.0 Core` release gate in GitHub issue #2 and `docs/DEVICE_TEST_CHECKLIST.md`.

## Previous signed Android build baseline

The following signed files were produced locally on **2026-09-03**, before the core-foundation` work:

- `TagVerity-1.0.0-arm64.apk`
- `TagVerity-1.0.0-arm64.aab`

Those files proved that Android release signing and packaging worked on the development machine, but they **must not be treated as containing the current core-foundation changes**. Rebuild signed release artifacts from merged `main` before any store upload.

The private upload keystore and `android/key.properties` remain local and are excluded from Git.

## Remaining v1.0 release gates

These require hardware, signing identities, or store accounts and therefore cannot be completed by repository CI alone:

- Complete the physical Android NFC matrix in issue #2.
- Complete the physical iPhone NFC matrix using a signed build.
- Produce a fresh signed Android APK/AAB from merged `main`.
- Produce a signed iOS Archive on macOS/Xcode.
- Complete Google Play / App Store listing assets and submission metadata.

## Scope boundary

TagVerity remains intentionally read-only. The core project does not include NFC writing/formatting, UID spoofing/cloning, key recovery, relay/replay tooling, protected-memory extraction, or an arbitrary APDU console.

For the current product plan, see `docs/ROADMAP.md`. For privacy behavior, see `PRIVACY_POLICY.md` and `docs/PRIVACY_MODEL.md`.
