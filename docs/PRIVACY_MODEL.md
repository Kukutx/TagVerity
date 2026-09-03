# Privacy model

## Data processed

TagVerity only processes NFC tags the user intentionally presents to the phone. A scan may contain:

- raw UID/platform identifier when exposed by the OS;
- SHA-256 fingerprint derived from the exposed identifier;
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

Batch results are held in application memory for the active app session. They are also saved to normal history using the same privacy policy as single scans. Batch CSV export is an explicit user action.

## Fingerprint limitation

A deterministic SHA-256 fingerprint is pseudonymous, not anonymous. If a platform exposes the same UID, the same fingerprint can correlate that tag across scans.

A future synced/team product should move to tenant-scoped keyed identifiers rather than treating raw SHA-256 as anonymous data.

## Diagnostics

Diagnostics remain in memory, are capped, and do not intentionally include raw UID, UID fingerprint, or NDEF payload. Identifier-like error text is redacted before storage/export.

## Clipboard exports

JSON and CSV exports are copied only after a user action. Clipboard contents may be visible to the OS or other apps depending on platform behavior, so users should treat exported data according to their environment.
