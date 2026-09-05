# TagVerity roadmap
TagVerity is developed **core-first**. Reliability, clear NFC semantics, privacy, and cross-platform behavior take priority over feature count.
## v1.0 Core
### Inspect
- [x] NFC availability detection and lifecycle-safe scanning.
- [x] NFC-A / NFC-B / ISO-DEP public metadata.
- [x] NFC-V / ISO 15693 polling and public metadata on Android and iOS.
- [x] NFC-F / ISO 18092 polling and public metadata on Android.
- [x] NFC Forum Type 3 / NDEF (`12FC`) NFC-F polling on iOS.
- [x] Conservative classification without pretending to identify proprietary applications.
- [x] Comparable vs session-only identity semantics.
- [x] PASS / LIMITED / REVIEW based on core read quality rather than NDEF presence.
- [x] Optional low-level metadata failures do not incorrectly force REVIEW.
### NDEF
- [x] Detect support, capacity, writable/read-only state, and read status.
- [x] Decode NFC Forum Text and URI records.
- [x] Decode UTF-8 and UTF-16 Text records.
- [x] Handle empty NDEF containers.
- [x] Handle malformed text, binary media payloads, and unknown URI prefixes safely.
- [x] Bound record summaries so unusual tags cannot flood the UI or exports.
### Batch
- [x] Manual one-tag-at-a-time batch scanning.
- [x] Continuous batch workflow that rearms only after the native reader session closes.
- [x] No hard-coded rearm timing delay.
- [x] Repeated-ID checks only when a comparable platform identifier is available.
- [x] Explicit session-only count when comparison is unavailable.
- [x] PASS / LIMITED / REVIEW totals calculated once per batch mutation.
- [x] 1000-scan capacity guard.
- [x] Lazy batch result rendering.
- [x] CSV export with identity reliability and repeated-ID status.
### History, privacy, and export
- [x] Local scan history and search with lazy result rendering.
- [x] Raw UID, NDEF content, and linkable technical identifiers disabled in history by default.
- [x] Transactional history mutations: UI only reports success after persistence succeeds.
- [x] Disabling sensitive retention is privacy-first: future retention stops before historical cleanup, and cleanup failure stays visible.
- [x] Corrupt local history/settings surface an error instead of silently pretending data is empty.
- [x] JSON export for scans/history and CSV export for batches.
- [x] Native Android/iOS sharing with failure reporting and old temporary-export cleanup.
- [x] Privacy-safe diagnostics.
### UX and quality
- [x] Global error banner visible from Inspect, Batch, History, and Settings.
- [x] Simplified Settings: NDEF + privacy controls; diagnostics moved to a dedicated page.
- [x] Technical detail visibility is local to the detail page instead of a global setting.
- [x] Only the active bottom-navigation page is built/listening.
- [x] Unit/controller coverage for decoding, classification, assessment, privacy, and batch identity rules.
- [x] Widget tests for navigation, global errors, sensitive-setting confirmation, a narrow phone surface, 200% text scaling, and dark mode.
- [x] CI version/schema consistency validation.
- [x] Android debug compile and unsigned iOS debug compile in GitHub Actions.
- [ ] Complete the physical-device matrix in `docs/DEVICE_TEST_CHECKLIST.md` and a signed iPhone Archive.
The final unchecked item requires real NFC hardware and signing and cannot be replaced by CI.
## After v1.0
Only after the core release gate is satisfied:
- Localization.
- Saved batch sessions and richer report summaries.
- User-defined validation rules for expected NDEF content.
- Import/export interoperability improvements.
- Accessibility and large-screen polish beyond the v1.0 smoke coverage.
- Optional inventory / asset workflows built on top of the read-only inspector.
## Non-goals
TagVerity does not plan to add cloning, UID spoofing, key recovery, relay/replay tooling, arbitrary APDU consoles, or protected-memory extraction. NFC writing/formatting is also outside the current core product scope.
