# Extension guide

## Principles

- Keep generic NFC scanning read-only.
- Keep platform/plugin code inside `data/`.
- Keep business logic in domain services and stable domain models.
- Keep privacy decisions explicit before persistence/export.

## Add a public metadata field

1. Read only a value already exposed by the platform NFC API.
2. Add a stable key in `NfcManagerReaderService`.
3. Add its user-facing label and privacy classification in `TagFactCatalog`.
4. Add tests if the field affects assessment, privacy, export, or UI filtering.

Do not add arbitrary transceive/APDU, authentication, protected reads, or writing to the generic scan path.

## Add a tag rule

Rules should consume `NfcScan` and produce a deterministic result. Keep rule logic independent from Flutter UI widgets.

Future product-specific validation profiles should build on the same model rather than hardcoding one vendor or card product into the NFC reader.

## Replace local storage

Implement `ScanHistoryRepository`. A database replacement should include schema migrations and preserve privacy defaults.

## Add export/share

Keep serialization and file/share platform logic outside `NfcScan`. Explicit user action should remain required for export.

## Add localization

UI copy and `TagFactCatalog` labels can move to Flutter localization resources without changing stable metadata keys.

## Upgrade Flutter/dependencies

1. Use the project's single installed Flutter SDK.
2. Upgrade on a branch.
3. Run format/analyze/tests.
4. Build Android and iOS platform targets.
5. Complete real-device NFC regression tests.
