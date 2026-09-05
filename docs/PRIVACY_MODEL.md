# Privacy model
## Data processed
TagVerity only processes NFC tags the user intentionally presents to the phone. A scan may contain:
- raw UID/platform identifier when exposed by the OS;
- SHA-256 fingerprint derived from that identifier when one is available, or a session-only fingerprint when no comparable identifier is exposed;
- NFC technology and public protocol metadata;
- standard NDEF record summaries and payload previews;
- scan time and core read warnings.
TagVerity has no account system, advertising SDK, analytics SDK, telemetry, network client, or background upload task.
## Current scan vs saved history
| Data | Current scan | Default history | Optional history |
|---|---:|---:|---:|
| Raw UID/platform identifier | shown when available | no | yes |
| SHA-256 fingerprint | yes | yes | yes |
| Non-linkable public metadata | yes | yes | yes |
| Selected linkable protocol fields | yes | no | yes |
| NDEF payload/summary | yes | no | yes |
Sensitive retention options are off by default. Enabling one requires explicit user confirmation.
Settings mutations are serialized and each queued change is applied against the latest committed settings, preventing rapid switch changes from overwriting one another.
Turning a sensitive retention option **off** is privacy-first: TagVerity first persists the disabled setting so future scans stop retaining that field, then rewrites existing history with the matching saved data removed. If historical cleanup fails, the setting remains disabled, the old saved data stays visible, and a global error tells the user to retry cleanup.
The Settings page also provides one **Remove sensitive saved data** action that removes saved raw UID, retained NDEF, and selected linkable technical fields together. Success is reported only after the local write succeeds.
Legacy pre-TagVerity history is migrated with raw UID, NDEF content, and selected linkable technical fields removed by default.
## Storage integrity
History and settings are stored locally through `shared_preferences` for the current small dataset. Persisted JSON is shape-validated on load.
Malformed/corrupted saved data is **not** silently converted into an empty history or default settings. The repository reports the failure to the controller, and the global error banner tells the user that local data could not be loaded. The original stored value is not intentionally overwritten during that failed read.
History creation, deletion, clearing, and privacy scrubbing are transactional from the UI perspective: in-memory saved history changes only after persistence succeeds. A failed write therefore cannot appear successful until the next app restart.
## Batch mode
Batch results are held in application memory for the active app session. Successful scans are also offered to normal history using the same privacy policy and transactional persistence behavior as a single scan.
Repeated-ID comparison is performed only for scans with a comparable platform-exposed identifier. Session-only fingerprints are never treated as proof of uniqueness. Batch CSV export is an explicit user action.
## Fingerprint limitation
When the platform exposes a comparable identifier, its deterministic SHA-256 fingerprint is pseudonymous, not anonymous, and may correlate that observed identifier across scans. Some NFC tags can randomize identifiers, so distinct fingerprints are not proof of distinct physical tags.
When no comparable identifier is exposed, TagVerity marks identity as `sessionOnly`. That generated fingerprint is not used for repeated-ID comparison and must not be interpreted as persistent physical-tag identity.
A future synced/team product should use tenant-scoped keyed identifiers instead of treating a raw SHA-256 fingerprint as anonymous data.
## Diagnostics
Diagnostics remain in memory, are capped, and do not intentionally include raw UID, UID fingerprint, or NDEF payload. Common long hexadecimal identifier text is redacted before events are retained/exported.
Diagnostics include product/runtime metadata and may include error messages. They are copied only after an explicit user action and are never uploaded automatically.
## Clipboard and share exports
JSON/CSV is exported only after a user action. Clipboard content may be visible to the OS or other apps depending on platform behavior.
For system-share exports, TagVerity writes a temporary UTF-8 file. Before writing a new report, the native Android/iOS share bridge removes older TagVerity temporary export files from its own cache/temp location so sensitive reports do not accumulate indefinitely. The destination chosen in the system share sheet is controlled by the user and operating system.
