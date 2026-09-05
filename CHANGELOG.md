# Changelog
## Unreleased
### Core NFC coverage and correctness
- Added NFC-V / ISO 15693 polling and public metadata support on Android and iOS.
- Added NFC-F / ISO 18092 public metadata support on Android.
- Added iOS NFC Forum Type 3 / NDEF polling using the standard FeliCa system code `12FC`; proprietary FeliCa system enumeration remains out of scope.
- Changed PASS / LIMITED / REVIEW semantics so a valid non-NDEF smart card can PASS; NDEF absence is informational, while NDEF read failures remain REVIEW.
- Optional low-level controller metadata failures are now best-effort and no longer incorrectly force REVIEW.
- Continuous Batch now rearms only after the native NFC session has actually closed, removing the previous hard-coded rearm delay.
### Deep-audit hardening
- Added scan request/session generation guards so rapid taps, stop-during-start, stale native callbacks, and old NFC sessions cannot corrupt a newer scan.
- Serialized all history persistence so scan saves, delete, clear, scrub, and privacy rewrites cannot overwrite each other from stale snapshots; one failed queued write no longer poisons later operations.
- Default saved history no longer retains a comparable tag fingerprint when technical identifiers are disabled; it keeps the scan event ID but replaces tag identity with a session-only per-scan fingerprint.
- Legacy pre-TagVerity history now replaces UID-derived stable fingerprints during migration instead of briefly carrying them into the current history key.
- NFC-F manufacturer/PMm-style metadata is now treated as linkable technical data and removed from privacy-minimized history.
- Persisted history validation now enforces the public export schema's SHA-256 fingerprint shape and unique technology list.
- Added startup privacy enforcement so previously retained sensitive history is hidden immediately and rewritten to match current settings.
- Added standard NFC Forum Type 4 / NDEF AID `D2760000850101` for iOS without claiming arbitrary ISO 7816 application discovery.
- Added recursive diagnostics sanitization, clean platform-error text, NFC availability timeout/failure handling, and false-success protection for clipboard copies.
- Fixed a narrow-screen / large-text `SectionCard` overflow found by a 320px + 200% text-scale stress test.
- Added per-process scan sequencing to event IDs to avoid timestamp-collision keys.
### Reliability, privacy, and performance
- Added a cached one-pass `BatchSummary` for quality and comparable-identity metrics.
- Switched Batch and History results to lazy list rendering and stopped building/listening to all four bottom-navigation pages at once.
- Added a global error banner so scan, storage, settings, and export failures are visible from every main tab.
- Made scan-history persistence transactional: failed saves no longer create history that appears saved until app restart.
- Made Settings and history mutations return success/failure explicitly; success UI is only shown after persistence succeeds.
- Turning sensitive retention off is now privacy-first: the stricter setting is committed first, in-memory history is scrubbed immediately, and the on-disk rewrite is serialized behind any in-flight history write.
- Malformed persisted history/settings now surfaces a storage error rather than silently appearing empty.
- Consolidated sensitive-history cleanup into one action.
- Native Android/iOS sharing now removes only `tagverity-*` temporary export files older than 24 hours, avoiding premature deletion while a receiving app may still be reading a report.
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
- Expanded automated coverage with scan-lifecycle races, serialized history mutations, SharedPreferences migration/corruption tests, recursive diagnostics redaction, report encoding, clipboard failures, availability/settings guards, and a 320px + 200% text-scale Tag Details stress test.
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
