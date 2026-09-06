# Scan export format

TagVerity scan/history JSON exports use schema version **3**.

```json
{
  "schemaVersion": 3,
  "app": "TagVerity",
  "appVersion": "1.0.0",
  "exportedAt": "2026-09-03T12:00:00.000Z",
  "readOnlyScope": true,
  "scans": []
}
```

Each scan contains:

- `id`
- `scannedAt`
- `platform`
- `uidHex`
- `uidFingerprint`
- `identityStability` (`stable`, `sessionOnly`, or `unknown`); `stable` means a platform identifier was available for comparison, not proof that a physical tag never randomizes its identifier
- `technologies`
- `details` using stable TagVerity fact keys
- `ndefRecords`
- `warnings`

The formal JSON Schema is `docs/nfc-scan-export.schema.json`.

TagVerity-generated v3 exports use colon-delimited hexadecimal bytes for non-null `uidHex`, `identifierHex`, and `payloadPreviewHex`. NDEF payload previews contain at most the first 64 payload bytes. Persistence and export encoders share the same model-level scan contract: preview length must match `min(payloadLength, 64)`, record indexes must match array order, `byteLength` cannot be smaller than `payloadLength`, technologies cannot repeat, and any retained raw UID must match its SHA-256 fingerprint plus comparable identity semantics. Invalid models are rejected before JSON or Batch CSV is produced. These constraints describe values TagVerity has generated throughout schema v3 rather than introducing a new export shape.

## Privacy note

Current-scan export can contain the raw UID and NDEF content visible on screen. History export contains only what history retained under the user's privacy settings. When raw UID retention is enabled, the history export also keeps the comparable SHA-256 fingerprint derived from that UID so the exported identity fields do not contradict each other.

Batch CSV is a separate compact QA export and contains scan time, short fingerprint, identity stability, technologies, NDEF record count, assessment status, warning count, and duplicate status. Session-only and unknown identities both export duplicate status as `unknown`; the Batch UI counts those two identity states separately.
