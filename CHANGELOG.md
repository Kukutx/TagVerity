# Changelog
## Unreleased
### Core NFC coverage and correctness
- Added NFC-V / ISO 15693 polling and public metadata support on Android and iOS.
- Added NFC-F / ISO 18092 public metadata support on Android.
- Added iOS NFC Forum Type 3 / NDEF polling using the standard FeliCa system code `12FC`; proprietary FeliCa system enumeration remains out of scope.
- Changed PASS / LIMITED / REVIEW semantics so a valid non-NDEF smart card can PASS; NDEF absence is informational, while NDEF read failures remain REVIEW.
- Optional low-level controller metadata failures are now best-effort and no longer incorrectly force REVIEW.
- Continuous Batch now rearms only after the native NFC session has actually closed, removing the previous hard-coded rearm delay.
### Reliability, privacy, and performance
- Added a cached one-pass `BatchSummary` for quality and comparable-identity metrics.
- Switched Batch and History results to lazy list rendering and stopped building/listening to all four bottom-navigation pages at once.
- Added a global error banner so scan, storage, settings, and export failures are visible from every main tab.
- Made scan-history persistence transactional: failed saves no longer create history that appears saved until app restart.
- Made Settings and history mutations return success/failure explicitly; success UI is only shown after persistence succeeds.
- Turning sensitive retention off now transactionally scrubs matching already-saved data.
- Malformed persisted history/settings now surfaces a storage error rather than silently appearing empty.
- Consolidated sensitive-history cleanup into one action.
- Native Android/iOS sharing now removes stale `tagverity-*` temporary export files before writing a new report.
- Hardened NDEF media summaries so binary MIME payloads are not displayed as decoded text.
### UX and maintainability
- Simplified Settings to NDEF reading plus privacy controls; moved runtime diagnostics to a dedicated page.
- Moved “show technical fields” from a global setting to a local toggle on Tag Details.
- Removed user-facing scan-timeout, history-limit, and NFC-sound settings in favor of stable product defaults.
- Added `ReportEncoder`, `DiagnosticsBuffer`, and `BatchSummary` helpers to reduce controller responsibility and repeated work.
- Added version/schema metadata validation so `pubspec.yaml`, `AppConstants`, and export schema versions cannot silently drift.
- Open-source bootstrap now accepts compatible SDKs by default while retaining maintainer-only `--strict-sdk --single-sdk` enforcement.
- Google Play store script now targets ARM32 + ARM64; the development APK remains ARM64-focused.
- Added Widget Tests for core navigation, global errors, and a 320px-wide phone surface.
- Expanded automated coverage to 52 tests in the local pre-PR validation run, including navigation, scan-state, error-banner, sensitive-setting, narrow-screen, 200% text-scale, and dark-mode Widget Tests.
### Previously completed core work
- Added comparable-ID vs session-only NFC identity semantics so repeated-ID checks never claim physical-tag uniqueness when the platform lacks a comparable identifier.
- Added conservative NFC tag classification without guessing proprietary applications.
- Hardened NDEF decoding for UTF-16, malformed text, binary payloads, unknown URI prefixes, empty tags, and bounded summaries.
- Added continuous Batch scanning with lifecycle/error stop conditions, capacity protection, and identity-aware CSV output.
- Added transactional privacy/history mutations, privacy-safe legacy migration, export schema v3, Android/iOS CI build gates, open-source contribution templates, protected `main`, Dependabot, secret scanning, and a physical-device v1.0 release gate.
## 1.0.0 - 2026-09-03
- Rebranded the project as **TagVerity**.
- Aligned the project with Flutter 3.47.1 and Dart 3.13.1.
- Removed transit-card-specific product behavior and the 90-minute reference timer.
- Added automatic tag assessment: PASS, LIMITED, REVIEW.
- Added batch sessions, repeated-ID detection, summary metrics, and CSV export.
- Added searchable scan history.
- Added stable public tag fact keys instead of display-text-dependent metadata keys.
- Added default scrubbing for selected linkable technical identifiers.
- Updated diagnostics, UI copy, privacy model, release documentation, and tests.
- Fixed Flutter 3.47 compatibility conflict with the app diagnostic severity enum.
