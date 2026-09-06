# TagVerity Privacy Policy

Last updated: 2026-09-06

TagVerity is designed to work without an account, analytics, advertising, or background data collection.

## Data TagVerity processes

TagVerity processes NFC tag information only when you explicitly start a scan and present a tag to your device. Depending on the device and tag, this may include public NFC technology metadata, a tag identifier exposed by the operating system, standard NDEF records, scan time, and local diagnostic information.

## Local storage

Scan history and settings are stored in app-local storage. By default, TagVerity does not save full raw UID values, NDEF content, comparable tag fingerprints, or linkable technical identifier fields in history. Default history also uses an explicit allowlist of reviewed non-linkable metadata; unknown or future technical fields are omitted unless they become part of the reviewed retention model. Scan warnings saved to history are reduced to bounded generic categories instead of retaining raw platform-error text.

These retention options can be changed by the user. Enabling linkable technical-identifier retention expands the history allowlist only to linkable keys that TagVerity explicitly catalogs; unknown or future detail keys remain excluded until they are reviewed and added to that catalog. Turning a sensitive retention option off first commits the setting so future scans stop retaining that field, then removes the matching already-saved data. If historical cleanup fails, the setting remains off and the global error banner explains that cleanup is incomplete. Settings also provides one action to remove all sensitive saved history fields together.

Legacy pre-TagVerity history is migrated with raw UID, UID-derived comparable fingerprints, old event IDs that embedded a fingerprint prefix, NDEF content, raw warning error payloads, and unreviewed/linkable technical fields removed by default. Once the current history copy is authoritative, the stale legacy history key is overwritten with an empty safe value before deletion is attempted, so a failed delete does not leave the original sensitive payload behind.

A comparable tag fingerprint may be retained when either raw UID retention or technical-identifier retention is enabled. If raw UID retention is enabled, TagVerity also retains the SHA-256 fingerprint derived from that same UID so the saved UID, fingerprint, and identity-stability fields remain consistent; the fingerprint does not disclose more identifier information than the already-retained raw UID. When the operating system exposes a comparable identifier, its deterministic fingerprint can correlate that observed identifier across scans and should not be treated as anonymous data. Otherwise, saved history uses a session-only per-scan value derived from non-tag event metadata and does not use it to claim duplicate or unique physical tags.

### Operating-system backups

On Android, TagVerity opts out of Android app-data backup and also supplies backup/data-extraction rules that exclude its app-private files, preferences, databases, and external app data from the Android Auto Backup and device-transfer mechanisms.

On iOS, TagVerity does not use iCloud key-value sync or a TagVerity cloud service. However, the `shared_preferences` storage used for settings/history maps to persistent system preferences, and iOS device backups may include those preferences according to the user's operating-system backup configuration. Such a device backup is controlled by Apple/iOS and the user, not uploaded to a TagVerity server.

## Sharing and exports

TagVerity does not automatically upload scan data. When you choose Copy, Share, or Export, the requested data is handed to the operating system clipboard or share sheet. Native share exports use a dedicated temporary/cache directory; TagVerity removes its temporary export files older than 24 hours so reports do not accumulate indefinitely while recent files remain available long enough for the receiving app to read them. What happens after you choose a destination is controlled by the operating system and destination app or service.

## Network access, analytics, and advertising

TagVerity contains no application account system, advertising SDK, analytics SDK, telemetry service, or automatic cloud synchronization. The core NFC inspection flow does not require a TagVerity server.

## Permissions

TagVerity requests NFC access only to inspect tags that you intentionally scan. It does not emulate, clone, write, or modify NFC tags.

## Data deletion

You can delete individual history items, clear all history, or use “Remove sensitive saved data” to remove stored raw UIDs, retained NDEF content, and stored linkable technical identifiers together. Disabling an individual sensitive retention setting also removes the matching saved data. Uninstalling the app removes its current local app container according to the operating system's behavior; a later restore from an operating-system backup is governed by that platform's backup behavior described above.

## Children

TagVerity is a general utility tool and is not directed specifically at children.

## Changes

If TagVerity later adds optional cloud services, accounts, analytics, or other data processing, this policy and the relevant in-app controls must be updated before those features are released.

## Contact

For general project support, use the public GitHub Issues page. For security-sensitive reports, use GitHub Private Vulnerability Reporting so sensitive information is not posted publicly.
