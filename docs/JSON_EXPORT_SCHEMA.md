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

## Privacy note

Current-scan export can contain the raw UID and NDEF content visible on screen. History export contains only what history retained under the user's privacy settings.

Batch CSV is a separate compact QA export and contains scan time, short fingerprint, identity stability, technologies, NDEF record count, assessment status, warning count, and duplicate status. Session-only identities export duplicate status as `unknown`.
