# TagVerity Privacy Policy

Last updated: 2026-09-05

TagVerity is designed to work without an account, analytics, advertising, or background data collection.

## Data TagVerity processes

TagVerity processes NFC tag information only when you explicitly start a scan and present a tag to your device. Depending on the device and tag, this may include public NFC technology metadata, a tag identifier exposed by the operating system, standard NDEF records, scan time, and local diagnostic information.

## Local storage

Scan history and settings are stored on your device. By default, TagVerity does not save full raw UID values, NDEF content, or linkable technical identifier fields in history. These options can be changed by the user. Turning a sensitive retention option off first commits the setting so future scans stop retaining that field, then removes the matching already-saved data. If historical cleanup fails, the setting remains off and the global error banner explains that cleanup is incomplete. Settings also provides one action to remove all sensitive saved history fields together. Legacy pre-TagVerity history is migrated with raw UID, NDEF content, and linkable technical identifier fields removed by default.

A tag fingerprint may be retained locally. When the operating system exposes a comparable identifier, its deterministic fingerprint can correlate that observed identifier across scans and should not be treated as anonymous data. When no comparable identifier is exposed, TagVerity marks the fingerprint as session-only and does not use it to claim duplicate or unique physical tags.

## Sharing and exports

TagVerity does not automatically upload scan data. When you choose Copy, Share, or Export, the requested data is handed to the operating system clipboard or share sheet. Native share exports use a temporary local file; TagVerity removes older TagVerity temporary export files before creating a new one so reports do not accumulate indefinitely. What happens after you choose a destination is controlled by the operating system and destination app or service.

## Network access, analytics, and advertising

TagVerity contains no application account system, advertising SDK, analytics SDK, telemetry service, or automatic cloud synchronization. The core NFC inspection flow does not require a TagVerity server.

## Permissions

TagVerity requests NFC access only to inspect tags that you intentionally scan. It does not emulate, clone, write, or modify NFC tags.

## Data deletion

You can delete individual history items, clear all history, or use “Remove sensitive saved data” to remove stored raw UIDs, retained NDEF content, and stored linkable technical identifiers together. Disabling an individual sensitive retention setting also removes the matching saved data. Uninstalling the app also removes its local app data according to the operating system's behavior.

## Children

TagVerity is a general utility tool and is not directed specifically at children.

## Changes

If TagVerity later adds optional cloud services, accounts, analytics, or other data processing, this policy and the relevant in-app controls must be updated before those features are released.

## Contact

For general project support, use the public GitHub Issues page. For security-sensitive reports, use GitHub Private Vulnerability Reporting so sensitive information is not posted publicly.
