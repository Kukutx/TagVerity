# Privacy model

## Data processed

TagVerity only processes NFC tags the user intentionally presents to the phone. A scan may contain:

- raw UID/platform identifier when exposed by the OS;
- SHA-256 fingerprint derived from the exposed identifier when one is available, or a session-only fingerprint when the platform exposes no stable identifier;
- NFC technology and public protocol metadata;
- standard NDEF record summaries and payload previews;
- scan time and read warnings.

TagVerity has no account system, advertising SDK, analytics SDK, telemetry, network client, or background upload task.

## Current scan vs history

| Data | Current scan | Default history | Optional history |
|---|---:|---:|---:|
| Raw UID | shown when available | no | yes |
| SHA-256 fingerprint | yes | yes | yes |
| Non-linkable public metadata | yes | yes | yes |
| Selected linkable protocol fields | yes | no | yes |
| NDEF payload/summary | yes | no | yes |

The settings page provides explicit cleanup actions for saved UID, NDEF, and linkable technical fields.

## Batch mode

Batch results are held in application memory for the active app session. They are also saved to normal history using the same privacy policy as single scans. Duplicate comparison is performed only for scans with a stable platform-exposed identifier; session-only fingerprints are never treated as proof of uniqueness. Batch CSV export is an explicit user action.

## Fingerprint limitation

When the platform exposes a comparable identifier, its deterministic SHA-256 fingerprint is pseudonymous, not anonymous, and can correlate that observed identifier across scans. Some NFC tags can randomize identifiers, so distinct IDs are not proof of distinct physical tags. When no stable identifier is exposed, TagVerity marks identity as `sessionOnly`; that fingerprint is not used for duplicate comparison and should not be interpreted as a persistent tag identity.

A future synced/team product should move to tenant-scoped keyed identifiers rather than treating raw SHA-256 as anonymous data.

## Diagnostics

Diagnostics remain in memory, are capped, and do not intentionally include raw UID, UID fingerprint, or NDEF payload. Identifier-like error text is redacted before storage/export.

## Clipboard exports

JSON and CSV exports are copied only after a user action. Clipboard contents may be visible to the OS or other apps depending on platform behavior, so users should treat exported data according to their environment.
