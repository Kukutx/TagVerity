# TagVerity validation report
Validation date: 2026-09-06
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
- the complete Flutter test suite with LCOV coverage collection;
- a minimum **75% line coverage** floor;
- Android debug APK compilation;
- unsigned Android release AAB compilation for `android-arm,android-arm64` plus ARM32/ARM64 runtime-entry and final merged-manifest NFC/no-INTERNET verification;
- unsigned iOS **release** compilation on macOS.
A green CI run does not replace physical NFC hardware testing.
## Local no-emulator validation for the deep-audit hardening work
Verified on the maintainer machine without launching an emulator:
- `dart run tool/validate_project.dart`: passed.
- Release-metadata validator negative probes: passed for missing Android NFC permission, broadened FileProvider scope, broken iOS Type 4 AID, broken TAG entitlement, broken Xcode entitlement wiring, and removal of the CI no-INTERNET marker; each mutation failed validation and was restored.
- Diagnostics-v4 validator negative probes: passed for a missing privacy-recovery field, event-cap drift, diagnostic string-bound drift, nested collection-limit drift, and nesting-depth drift; each mutation failed validation and the schema was restored.
- strict maintainer bootstrap with `--strict-sdk --single-sdk`: passed against Flutter 3.47.1 / Dart 3.13.1.
- `flutter analyze`: **0 issues**.
- `flutter test --coverage`: **175/175 tests passed**.
- Line coverage: **81.8% (1762/2153)**, above the enforced **75%** floor. Coverage growth is concentrated in controller/session concurrency, local persistence, privacy, accessibility, diagnostics, report encoding/contracts, and detail UI. Native tag-adapter lines that require real nfc_manager platform tag objects are explicitly excluded from LCOV and remain covered by compile gates plus the physical-device matrix.
- Widget coverage includes four-tab navigation, global error visibility, sensitive-setting confirmation, dark mode, **all four core tabs at 320px + 200% text scaling**, populated Inspect/Batch/History results at the same stress size, and a full Tag Details stress pass with technical/NDEF expansion.
- Android debug APK compilation: passed.
- Android debug AAB compilation with `android-arm,android-arm64`: passed.
- Android **release AAB** compilation with `android-arm,android-arm64`: passed (**32.1 MB**); both `armeabi-v7a` and `arm64-v8a` contain `libapp.so`/`libflutter.so`, and no x86_64 Flutter app runtime is packaged.
- Final release-AAB merged-manifest inspection: `android.permission.NFC` present, `android.hardware.nfc` present, and `android.permission.INTERNET` absent.
- A detached no-secrets CI simulation with no `android/key.properties` also produced the same **32.1 MB** release AAB and passed the ARM32/ARM64/no-x86 runtime-entry check, confirming the release compile gate does not require repository signing secrets.
- Release AAB signature verification: `jar verified`. The local upload certificate is self-signed, which is normal for an Android upload key; rebuild final store artifacts from merged `main`.
- iOS `Info.plist` and entitlements parse successfully; `Info.plist` includes NFC Forum Type 3 / NDEF FeliCa system code `12FC` and standard NFC Forum Type 4 / NDEF ISO 7816 AID `D2760000850101`.
The current direct dependencies are already at their latest resolvable versions. Flutter 3.47.1 emits a future Built-in Kotlin migration warning for the upstream `nfc_manager` plugin; there is no newer resolvable plugin release in the current dependency graph, and the warning does not fail the current Android build.
## Core behavior covered by code and automated tests
- NFC-A / NFC-B (ISO 14443), NFC-V (ISO 15693), and NFC-F (ISO 18092) polling.
- iOS NFC-F intentionally limited to the standard NFC Forum Type 3 / NDEF system code `12FC`.
- iOS standard NFC Forum Type 4 / NDEF selection enabled through declared AID `D2760000850101`; arbitrary ISO 7816 application enumeration is not claimed.
- Single-tag NFC inspection and availability/error handling.
- Scan start, stop, timeout/error recovery, and lifecycle-safe cancellation, including bounded native session-start/close waits, replacement blocking while either transition remains unresolved, automatic cleanup of late start success, timeout coverage while tag inspection is still pending, and suppression of success/rearm on unconfirmed closure.
- Conservative NFC tag classification without claiming proprietary application identity.
- Comparable-ID, session-only, and unknown identity semantics, including separate Batch counts so unknown is never mislabeled as session-only.
- Repeated-ID checks only when the platform exposes an identifier that can be compared.
- Optional low-level metadata failures do not incorrectly mark an otherwise readable tag as REVIEW.
- NDEF support, read status, capacity, writable/read-only state, empty-container handling, and safe binary media summaries.
- NDEF Text and URI decoding, strict UTF-8/UTF-16 handling, Text-RTD reserved-bit validation, UTF-16 surrogate-pair validation, valid whitespace-only text handling, rejection of unsafe C0/DEL/C1 display controls while preserving Tab/LF/CR, malformed payload handling, unknown URI prefixes, and summaries bounded to 300 Unicode characters total including any ellipsis.
- PASS / LIMITED / REVIEW semantics where non-NDEF tags can still pass and user-disabled NDEF reading is LIMITED rather than mislabeled as unsupported.
- Manual Batch and continuous Batch scanning without a fixed rearm delay.
- Cached single-pass Batch summary metrics with construction restricted to `fromScans`/`empty`; repeated-fingerprint state is immutable and contradictory externally assembled summaries cannot be created.
- Lazy Batch and History list construction for larger datasets.
- Global error visibility from every core tab.
- Serialized settings mutations merge against the latest committed state so rapid toggles cannot overwrite one another.
- If saved privacy settings are unreadable, controller initialization fails closed for history: the persisted history is not loaded or rewritten, scanning/Batch/policy-dependent history mutations are blocked, interim settings changes remain history-neutral, and explicit recovery is serialized behind pending settings changes before applying the complete current policy. A separate confirmed delete-only path clears persisted history without loading it, keeps recovery/scanning locked afterward, and preserves the hidden copy when clearing fails. The recovery UI is covered at 320px + 200% text scaling.
- Overlapping NFC availability refreshes use latest-request-wins semantics so an older slow result cannot overwrite newer support state, return a stale gate decision to a caller, or log a stale failure diagnostic.
- The real nfc_manager reader maps enabled/disabled/unsupported states directly while propagating native availability errors/timeouts to the controller, where they degrade to `unknown` and produce sanitized `nfc.availability.check.failed` diagnostics.
- Serialized history persistence across scan-save/delete/clear/scrub/privacy rewrites, including recovery after a failed queued write and deterministic behavior under concurrent user actions.
- Privacy-first sensitive-setting changes: the stricter setting commits first, sensitive history is hidden in memory immediately, disk rewrites are serialized, and startup reapplies/retries the current privacy policy if a previous rewrite was incomplete.
- Corrupted persisted history/settings are reported instead of silently becoming empty/default data.
- External/platform error text is normalized before the global banner and diagnostics path: control characters/whitespace are collapsed, blank errors get a stable fallback, and messages are bounded to 500 Unicode characters.
- Legacy settings cleanup is best-effort only after the current settings copy is committed; failure to remove the obsolete key no longer makes migrated/current settings load fail, and the stale key is first reduced to `{}` when possible.
- Searchable local history.
- Privacy-minimized history defaults and privacy-safe legacy migration, including replacement of legacy UID-derived fingerprints with session-only history fingerprints and replacement of early event IDs that embedded a fingerprint prefix.
- Raw UID retention keeps the matching SHA-256 comparable fingerprint and `stable` identity semantics; startup repairs older saved records that retained a raw UID with session-only identity metadata, and disabling raw UID retention scrubs the comparable fingerprint again unless technical-identifier retention remains enabled.
- Saved scan warnings are normalized to generic categories before history retention; malformed JSON parse failures use fixed messages rather than echoing persisted source text.
- Technical metadata retention is allowlist-based in both default and opt-in modes: opt-in adds only cataloged linkable keys, and unknown/future detail keys remain excluded and are scrubbed on startup.
- After current history becomes authoritative, the stale legacy history key is blanked before deletion is attempted so a failed remove cannot strand raw UID/NDEF data.
- NFC-F manufacturer/PMm-style metadata is treated as linkable technical data and scrubbed when technical-identifier retention is disabled.
- Persisted history rejects schema-incompatible fingerprints, malformed raw UIDs, duplicate technologies/scan IDs, non-sequential NDEF indexes, malformed NDEF identifier/preview hex, inconsistent NDEF preview/byte lengths, unknown scan/NDEF top-level fields, and more than the legacy-compatible 500 records; outgoing history is validated before it can replace the stored copy. Early current-v2 records without `identityStability` recover stable/session-only semantics from the original fingerprint construction.
- Persistence and JSON/CSV exports share the same scan contract for collection-level unique event IDs plus fingerprint/UID/identity consistency, technology uniqueness, and NDEF invariants. Export preparation failures surface as `export.encode.failed` instead of throwing through the UI or reporting false success.
- Batch CSV repeated-ID status is self-contained: the encoder derives comparable fingerprint counts from the exact scans being exported and accepts no external `BatchSummary`, preventing stale/mismatched summary state from changing report semantics.
- `NfcScan` collection fields are defensive immutable snapshots. Constructor/fromJson/copyWith inputs cannot mutate a completed scan later, direct getter mutation is rejected, and `toJson()` returns independent list/map copies so corruption-test/report DTO changes cannot back-mutate the source model.
- Scan/history JSON export schema **v3**.
- Diagnostics export schema **v4**, including explicit privacy-recovery state and bounded nested diagnostic values aligned with runtime limits.
- Native Android/iOS report sharing with failure reporting and 24-hour stale TagVerity temp-export cleanup; iOS exports use a TagVerity-specific temporary subdirectory.
- Android release manifest disables app-data backup and both legacy/full-backup and Android 12+ extraction rules exclude app-private files/DataStore, preferences, databases, root, and external app data; the project validator enforces the rule wiring.
- Privacy-safe diagnostics bounded by event count, string length, collection size, and nesting depth; recursively sanitized nested map/list values are immutable after retention, non-finite numbers are normalized before JSON encoding, and v4 exports explicitly identify privacy-settings recovery so hidden history counts are not misread.
- Simplified Settings surface with advanced tag facts moved to per-scan details.
- Current-tab-only page construction instead of rebuilding four always-mounted tab pages.
## Platform validation
Android and iOS project files, NFC permissions/entitlements, branding, and native share bridges are committed.
CI can verify Android debug/release compilation, release-AAB ABI plus final NFC/no-INTERNET manifest contents, static Android NFC/FileProvider policy, iOS usage/AID/TAG entitlement and Debug/Profile/Release project wiring, and an unsigned iOS release build. It cannot verify NFC antenna behavior, OS NFC session UX, device-specific tag support, Apple signing, or store submission.
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
