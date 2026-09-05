# TagVerity validation report
Validation date: 2026-09-05  
App version: 1.0.0+1
## Current validation baseline
TagVerity is a public, privacy-first, read-only NFC Inspector / Tag Checker / Batch Scanner.
Project compatibility and release baseline:
- Flutter **>= 3.47.1**
- Dart **>= 3.13.1**
- CI pinned to Flutter **3.47.1 / Dart 3.13.1**
- Android application ID: `dev.kukutx.tagverity`
- Android minSdk: 24
- Android targetSdk / compileSdk: 36
- iOS minimum: 13.0
- The maintainer Windows machine intentionally uses one Flutter SDK. Open-source contributors only need a compatible SDK.
GitHub Actions is the authoritative software merge gate. It requires:
- dependency resolution;
- Dart formatting;
- scan-export and diagnostics-export schema validation;
- app/schema version consistency validation;
- `flutter analyze`;
- the complete Flutter test suite;
- Android debug APK compilation;
- unsigned iOS debug compilation on macOS.
A green CI run does not replace physical NFC hardware testing.
## Local no-emulator validation for the core-v1-polish work
Verified on the maintainer machine without launching an emulator:
- `dart run tool/validate_project.dart`: passed.
- strict maintainer bootstrap with `--strict-sdk --single-sdk`: passed against Flutter 3.47.1 / Dart 3.13.1.
- `flutter analyze`: **0 issues**.
- `flutter test`: **54/54 tests passed**.
- Widget smoke coverage includes four-tab navigation, global error visibility, sensitive-setting confirmation, a 320px narrow viewport, 200% text scaling, and dark mode.
- Android debug APK compilation: passed.
- Android debug AAB compilation with `android-arm,android-arm64`: passed.
- Unsigned Android **release AAB** compilation with `android-arm,android-arm64`: passed (32.0 MB); both `armeabi-v7a` and `arm64-v8a` Flutter app libraries are present.
- iOS `Info.plist` parses successfully and includes the NFC Forum Type 3 / NDEF FeliCa system code `12FC`.
The current direct dependencies are already at their latest resolvable versions. Flutter 3.47.1 emits a future Built-in Kotlin migration warning for the upstream `nfc_manager` plugin; there is no newer resolvable plugin release in the current dependency graph, and the warning does not fail the current Android build.
## Core behavior covered by code and automated tests
- NFC-A / NFC-B (ISO 14443), NFC-V (ISO 15693), and NFC-F (ISO 18092) polling.
- iOS NFC-F intentionally limited to the standard NFC Forum Type 3 / NDEF system code `12FC`.
- Single-tag NFC inspection and availability/error handling.
- Scan start, stop, timeout/error recovery, and lifecycle-safe cancellation.
- Conservative NFC tag classification without claiming proprietary application identity.
- Comparable-ID vs session-only identity semantics.
- Repeated-ID checks only when the platform exposes an identifier that can be compared.
- Optional low-level metadata failures do not incorrectly mark an otherwise readable tag as REVIEW.
- NDEF support, read status, capacity, writable/read-only state, empty-container handling, and safe binary media summaries.
- NDEF Text and URI decoding, UTF-8/UTF-16 handling, malformed payload handling, unknown URI prefixes, and bounded summaries.
- PASS / LIMITED / REVIEW semantics where non-NDEF tags can still pass and user-disabled NDEF reading is LIMITED rather than mislabeled as unsupported.
- Manual Batch and continuous Batch scanning without a fixed rearm delay.
- Cached single-pass Batch summary metrics.
- Lazy Batch and History list construction for larger datasets.
- Global error visibility from every core tab.
- Serialized settings mutations merge against the latest committed state so rapid toggles cannot overwrite one another.
- Transactional history persistence plus privacy-first sensitive-setting changes: future retention stops before historical cleanup, and incomplete cleanup is surfaced globally.
- Corrupted persisted history/settings are reported instead of silently becoming empty/default data.
- Searchable local history.
- Privacy-minimized history defaults and privacy-safe legacy migration.
- Scan/history JSON export schema **v3**.
- Diagnostics export schema **v3**.
- Native Android/iOS report sharing with old TagVerity temp-export cleanup.
- Privacy-safe bounded diagnostics.
- Simplified Settings surface with advanced tag facts moved to per-scan details.
- Current-tab-only page construction instead of rebuilding four always-mounted tab pages.
## Platform validation
Android and iOS project files, NFC permissions/entitlements, branding, and native share bridges are committed.
CI can verify Android compilation and an unsigned iOS build. It cannot verify NFC antenna behavior, OS NFC session UX, device-specific tag support, Apple signing, or store submission.
The physical-device acceptance matrix remains the `v1.0 Core` release gate in GitHub issue #2 and `docs/DEVICE_TEST_CHECKLIST.md`.
## Previous signed Android build baseline
The signed files previously produced locally on **2026-09-03** were:
- `TagVerity-1.0.0-arm64.apk`
- `TagVerity-1.0.0-arm64.aab`
They prove that Android release signing and packaging worked on the maintainer machine, but they predate the current core-v1-polish work and **must not be uploaded as the current release**. Rebuild signed release artifacts from merged `main`.
The private upload keystore and `android/key.properties` remain local and are excluded from Git.
## Remaining v1.0 release gates
These require hardware, signing identities, or store accounts and cannot be completed by repository CI alone:
- Complete the physical Android NFC matrix, including NFC-V when available and NFC-F when available.
- Complete the physical iPhone NFC matrix using a signed build, including ISO 15693 and Type 3/NDEF where test tags are available.
- Produce a fresh signed Android APK/AAB from merged `main`.
- Produce a signed iOS Archive on macOS/Xcode.
- Complete Google Play / App Store screenshots, support URL, privacy-policy URL, and submission metadata.
## Scope boundary
TagVerity remains intentionally read-only. The core project does not include NFC writing/formatting, UID spoofing/cloning, key recovery, relay/replay tooling, protected-memory extraction, or an arbitrary APDU console.
For the current product plan, see `docs/ROADMAP.md`. For privacy behavior, see `PRIVACY_POLICY.md` and `docs/PRIVACY_MODEL.md`.
