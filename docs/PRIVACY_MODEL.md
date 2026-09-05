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
| Comparable tag fingerprint | yes when available | no (replaced with a session-only per-scan value) | yes |
| Reviewed non-linkable public metadata | yes | yes | yes |
| Unknown/future technical metadata | yes when exposed by this build | no | only after it is explicitly added to the retention model |
| Selected linkable protocol fields | yes | no | yes |
| NDEF payload/summary | yes | no | yes |
Sensitive retention options are off by default. Enabling one requires explicit user confirmation.
Settings mutations are serialized and each queued change is applied against the latest committed settings, preventing rapid switch changes from overwriting one another.
Turning a sensitive retention option **off** is privacy-first: TagVerity first persists the disabled setting so future scans stop retaining that field, immediately removes matching data from the in-memory/UI copy, then queues the history rewrite behind any history write already in flight. If cleanup fails, the setting remains disabled, sensitive data stays hidden in the running app, and a global error reports incomplete on-disk cleanup. On the next launch, loaded history is filtered through the current privacy settings again and TagVerity retries the privacy rewrite when needed.
The Settings page also provides one **Remove sensitive saved data** action that removes saved raw UID, retained NDEF, and selected linkable technical fields together. Success is reported only after the local write succeeds.
Legacy pre-TagVerity history is migrated with raw UID, UID-derived comparable fingerprints, NDEF content, raw warning error payloads, and linkable/unreviewed technical fields removed by default. Early scan event IDs that embedded the first 12 hexadecimal characters of a UID-derived fingerprint are also replaced with non-tag event IDs. Once the current history key is authoritative, the stale legacy history key is overwritten with an empty safe value before deletion is attempted.
## Storage integrity
History and settings are stored locally through `shared_preferences` for the current small dataset. Persisted JSON is shape-validated on load, including schema-critical fingerprint format and technology-list uniqueness.
Malformed/corrupted saved data is **not** silently converted into an empty history or default settings. JSON parser failures are reported with a fixed message rather than echoing the malformed source text, so a corrupt record cannot copy raw saved content into the global error or diagnostics path. The original current stored value is not intentionally overwritten during that failed read.
History disk mutations are serialized so scan saves, delete, clear, and privacy rewrites cannot overwrite one another from stale snapshots. Normal delete/clear/manual-scrub actions update the saved-history UI only after persistence succeeds. Disabling a retention setting is intentionally stricter: sensitive fields are hidden in memory immediately after the setting is committed, even if the queued disk rewrite fails.
Saved warning strings are normalized to a small set of generic warning categories before history retention. Raw platform exception text is not used as a history data channel.
Default technical metadata retention is allowlist-based. Only explicitly reviewed non-linkable keys are kept; unknown or future keys are dropped from default history and are removed by the startup privacy rewrite if they are found in older saved records.
## Operating-system backup boundary
On Android, TagVerity sets `android:allowBackup="false"` and supplies both Android 11-and-lower full-backup rules and Android 12+ data-extraction rules. Those rules exclude the app's file/DataStore, shared-preference, database, root, and external app-data domains from Android cloud backup and device transfer. The project validator checks that these protections remain present.
On iOS, `shared_preferences` uses persistent system preferences (`UserDefaults`). TagVerity does not use `NSUbiquitousKeyValueStore`, iCloud key-value synchronization, or a TagVerity cloud backend, but persistent defaults can be included in the user's operating-system device backup. This is an OS/user backup boundary rather than application-initiated synchronization. Temporary share exports live under the system temporary directory, which is separate from persistent history storage.
## Batch mode
Batch results are held in application memory for the active app session. Successful scans are also offered to normal history using the same privacy policy and transactional persistence behavior as a single scan.
Repeated-ID comparison is performed only for scans with a comparable platform-exposed identifier. Session-only fingerprints are never treated as proof of uniqueness. Batch CSV export is an explicit user action.
## Fingerprint limitation
When the platform exposes a comparable identifier, its deterministic SHA-256 fingerprint is pseudonymous, not anonymous, and may correlate that observed identifier across scans. Some NFC tags can randomize identifiers, so distinct fingerprints are not proof of distinct physical tags.
When no comparable identifier is exposed, TagVerity marks identity as `sessionOnly`. Default saved history also replaces comparable tag fingerprints with a session-only per-scan fingerprint derived from a privacy-safe event ID plus non-tag event metadata. These generated values are not used for repeated-ID comparison and must not be interpreted as persistent physical-tag identity.
A future synced/team product should use tenant-scoped keyed identifiers instead of treating a raw SHA-256 fingerprint as anonymous data.
## Diagnostics
Diagnostics remain in memory, are capped by event count, string length, collection size, and nesting depth, and do not intentionally include raw UID, UID fingerprint, or NDEF payload. Diagnostic messages and nested map/list data are recursively sanitized; colon-delimited and compact hexadecimal identifier-like values are redacted before events are retained/exported.
Diagnostics include product/runtime metadata and may include error messages. They are copied only after an explicit user action and are never uploaded automatically.
## Clipboard and share exports
JSON/CSV is exported only after a user action. Clipboard content may be visible to the OS or other apps depending on platform behavior.
For system-share exports, TagVerity writes a temporary UTF-8 file into a TagVerity-specific cache/temp directory. Before writing a new report, the native Android/iOS share bridge removes TagVerity temporary export files older than 24 hours from that directory. Recent files are kept long enough for the receiving app to read them. The destination chosen in the system share sheet is controlled by the user and operating system.
