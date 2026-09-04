# TagVerity Privacy Policy

Last updated: 2026-09-05

TagVerity is designed to work without an account, analytics, advertising, or background data collection.

## Data TagVerity processes

TagVerity processes NFC tag information only when you explicitly start a scan and present a tag to your device. Depending on the device and tag, this may include public NFC technology metadata, a tag identifier exposed by the operating system, standard NDEF records, scan time, and local diagnostic information.

## Local storage

Scan history and settings are stored on your device. By default, TagVerity does not save full raw UID values, NDEF content, or linkable technical identifier fields in history. These options can be changed by the user and previously stored sensitive fields can be removed from Settings. Legacy pre-TagVerity history is migrated with raw UID, NDEF content, and linkable technical identifier fields removed by default.

A tag fingerprint may be retained locally. When the operating system exposes a comparable identifier, its deterministic fingerprint can correlate that observed identifier across scans and should not be treated as anonymous data. When no comparable identifier is exposed, TagVerity marks the fingerprint as session-only and does not use it to claim duplicate or unique physical tags.

## Sharing and exports

TagVerity does not automatically upload scan data. When you choose Copy, Share, or Export, the requested data is handed to the operating system clipboard or share sheet. What happens after that is controlled by the destination app or service you choose.

## Network access, analytics, and advertising

TagVerity contains no application account system, advertising SDK, analytics SDK, telemetry service, or automatic cloud synchronization. The core NFC inspection flow does not require a TagVerity server.

## Permissions

TagVerity requests NFC access only to inspect tags that you intentionally scan. It does not emulate, clone, write, or modify NFC tags.

## Data deletion

You can delete individual history items, clear all history, remove stored raw UIDs, remove stored NDEF content, and remove stored linkable technical identifiers from inside the app. Uninstalling the app also removes its local app data according to the operating system's behavior.

## Children

TagVerity is a general utility tool and is not directed specifically at children.

## Changes

If TagVerity later adds optional cloud services, accounts, analytics, or other data processing, this policy and the relevant in-app controls must be updated before those features are released.

## Contact

For general project support, use the public GitHub Issues page. For security-sensitive reports, use GitHub Private Vulnerability Reporting so sensitive information is not posted publicly.
