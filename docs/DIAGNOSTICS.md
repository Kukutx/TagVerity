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
The event list is bounded by `AppConstants.maximumDiagnosticEvents`. Each diagnostic string is capped at 500 characters, collections at 20 items, and nested data at 4 levels; clearing diagnostics removes the in-memory buffer immediately. Sanitized nested maps/lists are retained as recursively unmodifiable snapshots, so consumers cannot mutate a redacted event after it enters the buffer. Non-finite numeric values such as NaN or infinity are normalized to a safe string marker before JSON encoding.
The user can explicitly copy diagnostics JSON. The export uses schema version 4 and includes current settings, NFC support state, visible in-memory history count, batch count, `privacySettingsRecoveryRequired`, and the bounded event list. When privacy recovery is required, saved history remains intentionally hidden and `historyCount` therefore does not imply that persisted history is empty.
Formal schema: `docs/diagnostics-export.schema.json`.
Diagnostics are not sent to a server or uploaded in the background.
