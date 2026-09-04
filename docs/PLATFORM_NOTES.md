# Platform notes

## Android

- Android continuous Batch rearms a new read session after each successful tag and stops on error, timeout, manual stop, batch finish, app backgrounding, or capacity limit.
- Android generally exposes more NFC tag metadata than iOS.
- UID and technology availability depend on the phone NFC controller and Android stack.
- MIFARE Classic support is hardware-dependent; TagVerity reports only what the phone exposes.
- Antenna position varies by device. Thick cases, metal accessories, or multiple contactless cards can reduce read reliability.

## iOS

- Core NFC presents the system scan sheet; TagVerity cannot provide Android-style silent continuous polling. Continuous Batch on iOS rearms by starting a new Core NFC session, so the system sheet may reopen between tags.
- iOS may expose fewer tag identifiers and protocol fields than Android. When no stable tag identifier is exposed, TagVerity marks identity as session-only and does not use that fingerprint for duplicate comparison.
- Missing UID or metadata does not mean the physical tag is empty or defective.
- A real iPhone, valid signing Team, NFC Tag Reading entitlement, and usage description are required.

## Assessment meaning

- **PASS**: the basic read completed with no inspection warnings.
- **LIMITED**: the tag responded, but the current platform exposes limited information.
- **REVIEW**: one or more read checks produced warnings or incomplete technology information.

These labels are inspection summaries, not authenticity or security guarantees.

## Troubleshooting order

1. Confirm NFC works with a known standard NDEF test tag.
2. Move the tag around the phone antenna area and keep it still briefly.
3. Check TagVerity diagnostics.
4. Test the same tag on another NFC-capable device if possible.
5. Separate phone compatibility issues from tag-specific behavior before treating a tag as defective.
