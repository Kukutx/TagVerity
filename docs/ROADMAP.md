# TagVerity roadmap

TagVerity is developed **core-first**. Reliability, clear NFC semantics, privacy, and cross-platform behavior take priority over feature count.

## v1.0 Core

### Inspect
- [x] NFC availability detection.
- [x] Start, stop, timeout, cancellation, and lifecycle-safe scanning.
- [x] Public ISO 14443 / NFC technology metadata.
- [x] Conservative tag classification without pretending to identify proprietary applications.
- [x] Stable vs session-only identity semantics.
- [x] PASS / LIMITED / REVIEW assessment.

### NDEF
- [x] Detect NDEF support, capacity, writable/read-only state, and read status.
- [x] Decode NFC Forum Text and URI records.
- [x] Decode UTF-8 and UTF-16 Text records.
- [x] Handle empty NDEF containers.
- [x] Handle malformed text, binary payloads, and unknown URI prefixes safely.
- [x] Bound record summaries so unusual tags cannot flood the UI or exports.

### Batch
- [x] Manual one-tag-at-a-time batch scanning.
- [x] Continuous batch workflow that rearms after each successful read.
- [x] Duplicate detection only when a comparable platform identifier is available.
- [x] Explicit session-only identity count when duplicate comparison is unavailable.
- [x] PASS / LIMITED / REVIEW batch totals.
- [x] Capacity guard instead of silently dropping scans.
- [x] CSV export with identity reliability and duplicate status.

### History, privacy, and export
- [x] Local scan history and search.
- [x] Raw UID, NDEF content, and linkable technical identifiers disabled in history by default.
- [x] Cleanup actions for already-saved sensitive data.
- [x] JSON export for scans/history.
- [x] CSV export for batches.
- [x] Native Android/iOS sharing with failure reporting.
- [x] Privacy-safe diagnostics.

### Quality and platforms
- [x] Flutter 3.47.1 / Dart 3.13.1 baseline.
- [x] Android and iOS projects committed and configured for NFC.
- [x] Automated formatting, schema checks, analysis, tests, Android build, and unsigned iOS compile in GitHub Actions.
- [x] Unit coverage for decoding, classification, assessment, privacy, and batch identity rules.
- [ ] Complete the physical-device matrix in `docs/DEVICE_TEST_CHECKLIST.md` on representative Android devices and a signed iPhone build.

The final unchecked item requires real NFC hardware and cannot be replaced by CI.

## After v1.0

Only after the core release gate is satisfied:

- Localization.
- Saved batch reports and richer report summaries.
- User-defined validation rules for expected NDEF content.
- Import/export interoperability improvements.
- Accessibility and large-screen polish.
- Optional inventory / asset workflows built on top of the read-only inspector.

## Non-goals

TagVerity does not plan to add cloning, UID spoofing, key recovery, relay/replay tooling, or arbitrary APDU consoles. NFC writing/formatting is also outside the current core product scope.
