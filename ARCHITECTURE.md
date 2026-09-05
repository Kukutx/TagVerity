# Architecture
## Product layers
### Domain
The domain layer is plugin-independent and contains:
- `NfcScan`: normalized read-only scan snapshot;
- `TagAssessment`: PASS / LIMITED / REVIEW based on core read quality;
- `TagClassifier`: conservative family classification without proprietary-app guessing;
- `TagFactCatalog`: stable metadata labels, advanced-field flags, and privacy classification;
- `BatchSummary`: one-pass batch quality and identity metrics;
- `ReportEncoder`: JSON/CSV encoding kept out of UI state;
- `DiagnosticsBuffer`: bounded, redacted in-memory diagnostics;
- `ScanSettings`: minimal NDEF/privacy settings;
- repository and export contracts.
### Data
`NfcManagerReaderService` is the NFC-plugin boundary. It:
- polls ISO 14443, ISO 15693, and ISO 18092;
- normalizes Android/iOS tag objects into `NfcScan`;
- treats optional controller metadata as best-effort instead of a health failure;
- keeps core NDEF read failures explicit;
- closes the native NFC session before delivering a successful scan to the controller, which makes continuous Batch rearming deterministic instead of timer-based.
On iOS, NFC-F polling is intentionally constrained to the NFC Forum Type 3 / NDEF system code `12FC` declared in `Info.plist`; TagVerity does not enumerate arbitrary proprietary FeliCa systems.
`SharedPreferencesScanHistoryRepository` persists the small local settings/history dataset. Malformed persisted data throws a visible storage error instead of silently becoming an empty history. The repository remains replaceable behind its interface if a database is needed later.
### Presentation
`NfcScanController` coordinates only stateful product workflows:
- NFC availability and scan lifecycle;
- single scans and continuous/manual Batch sessions;
- transactional settings/history persistence;
- privacy-minimized history;
- calls to report/share services.
Batch calculations, report encoding, and diagnostic buffering live in their dedicated domain helpers instead of being repeatedly recomputed in the controller.
The shell builds only the currently selected Inspect / Batch / History / Settings page. Batch and History use lazy list builders so large local result sets do not eagerly construct every tile on every controller notification.
A shell-level error banner exposes storage, export, and scan failures from whichever tab the user is currently viewing.
## Assessment semantics
- **PASS**: the core NFC read completed with no warnings. NDEF is not required.
- **LIMITED**: a user-disabled optional read (currently NDEF content) prevents the full optional inspection.
- **REVIEW**: a core read failed or no usable technology stack was exposed.
Optional max-transceive, timeout, or similar low-level metadata failures do not by themselves force REVIEW.
## Stable tag facts
Platform metadata uses stable keys such as `nfca.sak`, `nfcv.dsfId`, `nfcf.systemCode`, `ndef.supported`, and `isodep.historicalBytes`. UI labels are resolved separately through `TagFactCatalog`.
This prevents business logic from depending on display strings and keeps future localization, reports, validation rules, and migrations safer.
## Privacy boundary
Raw UID, NDEF payloads, and selected linkable protocol fields have separate retention decisions and are off by default. A change from retained -> not retained is transactional: matching already-saved data is scrubbed before the setting update is committed.
History mutations update UI only after persistence succeeds. Failed writes therefore do not create “deleted until restart” or “saved until restart” illusions.
## NFC safety boundary
The generic NFC path remains read-only. New decoders or rules may interpret already-exposed public metadata, but TagVerity does not add arbitrary APDU/transceive consoles, authentication attempts, tag writing, cloning, relay/replay, or protected-memory extraction.
## Toolchain and open-source policy
CI is pinned to Flutter 3.47.1 / Dart 3.13.1 for reproducibility. Open-source contributors may use compatible newer SDKs. The maintainer machine can opt into exact-version plus one-SDK-on-PATH enforcement with `--strict-sdk --single-sdk` without imposing that machine policy on contributors.
## Test boundary
- utilities, models, classifier, assessor, reports: unit tests;
- controller/history/batch transactions: fake NFC/repository tests;
- core navigation, global error handling, narrow-screen layout: Widget Tests;
- plugin/platform integration: Android build + unsigned iOS build in CI;
- RF behavior, antenna differences, NFC family compatibility, iOS signing: physical-device validation.
