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
- Native NFC session start and close transitions are each bounded to 5 seconds for UI recovery, while the fixed 30-second scan timeout remains active through tag inspection. A timed-out/pending native future is never treated as canceled: replacement sessions stay blocked, late start success is automatically closed, and the pending lock transitions from start to cleanup-close without an unlock gap. Duplicate discoveries remain ignored while one inspection owns the session.
- Serialized all history persistence so scan saves, delete, clear, scrub, and privacy rewrites cannot overwrite each other from stale snapshots; one failed queued write no longer poisons later operations.
- Default saved history no longer retains a comparable tag fingerprint when neither raw UID nor technical identifiers are retained; it keeps the scan event ID but replaces tag identity with a session-only per-scan fingerprint. Raw UID opt-in keeps the matching SHA-256 fingerprint/comparable identity so the saved identity fields remain consistent.
- Legacy pre-TagVerity history now replaces UID-derived stable fingerprints during migration instead of briefly carrying them into the current history key.
- NFC-F manufacturer/PMm-style metadata is now treated as linkable technical data and removed from privacy-minimized history.
- Persisted history validation now enforces SHA-256 fingerprint shape, byte-formatted raw UIDs, unique technologies/scan IDs, sequential NDEF indexes, strict NDEF identifier/preview hex, preview-length and payload-vs-record-length consistency, known scan/NDEF top-level fields, and the legacy-compatible 500-record ceiling; the same validation runs before saving so malformed outgoing history cannot replace a known-good copy. Early pre-identity v2 fingerprints recover their original stable-vs-session-only meaning before current privacy settings are reapplied.
- Persistence plus JSON/CSV export now share one model-level scan contract. Raw UID retention must match its SHA-256 fingerprint and comparable identity, and export preparation failures surface cleanly instead of producing schema-invalid reports or uncaught UI errors.
- Legacy scan IDs that embedded the first 12 hexadecimal characters of a UID-derived fingerprint are replaced with privacy-safe event IDs during migration/startup cleanup.
- Legacy warning strings and malformed-JSON errors no longer carry raw platform or persisted payload text into saved history/global diagnostics.
- Once the current history key is authoritative, the stale legacy history key is overwritten with an empty value before deletion so a failed remove cannot strand raw UID/NDEF data; legacy settings cleanup is best-effort after the current settings copy is committed, so a failed old-key removal cannot make migrated settings appear to fail.
- Technical metadata retention now uses an explicit reviewed allowlist in both default and opt-in modes; opting in adds only known linkable keys, while unknown/future detail keys remain excluded until explicitly cataloged.
- Android app-data backup/device-transfer paths are explicitly disabled/excluded, including the DataStore/file and legacy SharedPreferences domains.
- Added latest-request-wins guards for overlapping NFC availability refreshes so stale results cannot overwrite newer state, return stale gate decisions to callers, or emit stale failure diagnostics.
- Real nfc_manager availability timeout/platform failures now propagate to the controller instead of being silently converted inside the reader service, so production failures use the same unknown-state fallback and sanitized failure diagnostics already covered by controller tests.
- Added startup privacy enforcement so previously retained sensitive history is hidden immediately and rewritten to match current settings.
- Added standard NFC Forum Type 4 / NDEF AID `D2760000850101` for iOS without claiming arbitrary ISO 7816 application discovery.
- Added recursive diagnostics sanitization, bounded/normalized platform-error text (500 Unicode characters with control/whitespace cleanup), NFC availability timeout/failure handling, and false-success protection for clipboard copies.
- Bounded individual diagnostic strings, collections, and nesting depth so malformed runtime data cannot inflate troubleshooting exports.
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
- Native Android/iOS sharing now removes only `tagverity-*` temporary export files older than 24 hours, avoiding premature deletion while a receiving app may still be reading a report; iOS exports are isolated under a TagVerity-specific temporary subdirectory.
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
- Added combined 320px + 200% text-scale smoke coverage for all core tabs plus populated Inspect/Batch/History results; fixed the responsive Inspect status header, status badge, and Batch metric grid uncovered by that stress pass.
- Added a 75% minimum line-coverage gate to the local check scripts and GitHub CI; the hardened baseline currently exceeds it.
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
