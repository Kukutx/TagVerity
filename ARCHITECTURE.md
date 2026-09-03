# Architecture

## Product layers

### Domain

The domain layer is plugin-independent and contains:

- `NfcScan`: normalized read-only scan snapshot;
- `TagAssessment`: PASS / LIMITED / REVIEW result;
- `TagFactCatalog`: stable public metadata keys, labels, advanced-field flags, and privacy classification;
- `ScanSettings`: scan and privacy settings;
- repository contracts.

### Data

`NfcManagerReaderService` is the only NFC-plugin adapter. It converts Android/iOS NFC objects into stable domain data without exposing plugin objects to the rest of the app.

`SharedPreferencesScanHistoryRepository` persists small local history/settings. It can later be replaced by a database behind the same repository contract.

### Presentation

`NfcScanController` coordinates:

- NFC availability and session lifecycle;
- single-tag scans;
- batch sessions and duplicate detection;
- privacy-scrubbed history;
- JSON/CSV exports;
- diagnostics.

The main product surfaces are Inspect, Batch, History, and Settings.

## Stable tag facts

Platform metadata uses stable keys such as `nfca.sak`, `ndef.supported`, and `isodep.historicalBytes`. UI labels are resolved separately through `TagFactCatalog`.

This prevents business logic from depending on translated display text and makes future localization, rules, reports, and migrations safer.

## Privacy boundary

Raw UID, NDEF payloads, and selected linkable protocol fields have separate retention decisions. Default history is minimized before persistence.

## NFC boundary

The default NFC path remains read-only. New decoders or rules may interpret already-read public metadata, but generic scanning must not gain arbitrary APDU, authentication, writing, cloning, or replay behavior.

## Platform projects

TagVerity is aligned to Flutter 3.47.1 / Dart 3.13.1 and is intended to keep generated Android/iOS platform projects in the repository for reproducible store builds.

## Test boundary

- utilities and models: unit tests;
- tag assessment/privacy rules: unit tests;
- controller/history/batch behavior: fake NFC service tests;
- plugin API integration: analyze/build checks;
- RF behavior and real NFC compatibility: physical-device validation.
