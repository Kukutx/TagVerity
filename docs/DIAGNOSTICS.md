# Diagnostics

TagVerity keeps a small redacted diagnostic event buffer in memory for troubleshooting.

Diagnostics include:

- app initialization;
- NFC availability changes;
- scan start/stop/completion/errors;
- batch start/finish summary;
- settings changes;
- local storage failures.

Diagnostics intentionally do not include raw UID, UID fingerprint, or NDEF payload. Identifier-like hexadecimal text is redacted before it is retained.

The user can explicitly copy diagnostics JSON from Settings. The export uses schema version 2 and includes current settings, NFC support state, history count, batch count, and the bounded event list.

Formal schema: `docs/diagnostics-export.schema.json`.
