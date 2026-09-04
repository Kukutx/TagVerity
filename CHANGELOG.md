# Changelog

## Unreleased

- Added stable vs session-only NFC identity semantics so duplicate detection never claims certainty when the platform lacks a stable identifier.
- Added conservative NFC tag classification without guessing proprietary applications.
- Hardened NDEF decoding for UTF-16, malformed text, binary payloads, unknown URI prefixes, empty tags, and bounded summaries.
- Added explicit NDEF read states and improved PASS / LIMITED / REVIEW assessment.
- Added continuous Batch scanning with safe rearming, lifecycle/error stop conditions, capacity protection, and identity-aware CSV output.
- Added controller error-path coverage, identity compatibility tests, export schema v3, and schema validation in CI.
- Added core-first Roadmap, Issue/PR templates, Code of Conduct, and a physical-device v1.0 release gate.

## 1.0.0 - 2026-09-03

- Rebranded the project as **TagVerity**.
- Aligned the project with Flutter 3.47.1 and Dart 3.13.1.
- Removed transit-card-specific product behavior and the 90-minute reference timer.
- Added automatic tag assessment: PASS, LIMITED, REVIEW.
- Added batch sessions, duplicate detection, summary metrics, and CSV export.
- Added searchable scan history.
- Added stable public tag fact keys instead of display-text-dependent metadata keys.
- Added default scrubbing for selected linkable technical identifiers.
- Updated diagnostics, UI copy, privacy model, release documentation, and tests.
- Fixed Flutter 3.47 compatibility conflict with the app diagnostic severity enum.
