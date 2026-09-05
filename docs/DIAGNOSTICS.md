# Diagnostics
TagVerity keeps a small redacted diagnostic event buffer **in memory** for troubleshooting. Diagnostics are available from **Settings → Diagnostics**.
Diagnostics may include:
- app initialization;
- NFC availability changes;
- scan start/stop/completion/errors;
- manual/continuous Batch lifecycle summaries;
- settings changes;
- local storage failures;
- report-sharing failures.
The Diagnostics page also reports the current runtime baseline and polling scope:
- ISO 14443 / NFC-A and NFC-B;
- ISO 15693 / NFC-V;
- ISO 18092 / NFC-F;
- on iOS, NFC-F polling is constrained to the NFC Forum Type 3 / NDEF system code `12FC`.
Diagnostics intentionally do not include raw UID, UID fingerprint, or NDEF payload. Identifier-like long hexadecimal text is redacted before it is retained.
The event list is bounded by `AppConstants.maximumDiagnosticEvents`; clearing diagnostics removes the in-memory buffer immediately.
The user can explicitly copy diagnostics JSON. The export uses schema version 3 and includes current settings, NFC support state, history count, batch count, and the bounded event list.
Formal schema: `docs/diagnostics-export.schema.json`.
Diagnostics are not sent to a server or uploaded in the background.
