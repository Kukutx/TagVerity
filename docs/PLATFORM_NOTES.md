# Platform notes
## Android
- Polling covers NFC-A / NFC-B (`ISO 14443`), NFC-V (`ISO 15693`), and NFC-F (`ISO 18092`).
- Continuous Batch starts a new reader session only after the previous native session has closed; there is no timing-based rearm delay.
- Android generally exposes more low-level NFC metadata than iOS.
- Optional controller metadata such as timeout/max-transceive values is best-effort and does not make an otherwise healthy tag fail assessment.
- UID and technology availability depend on the phone NFC controller and Android stack.
- MIFARE Classic support is hardware-dependent; TagVerity reports only what the phone exposes.
- Antenna position varies by device. Thick cases, metal accessories, or multiple contactless cards can reduce read reliability.
### Current Flutter/Kotlin upstream note
With Flutter 3.47.1, the current `nfc_manager` release emits a warning that the plugin still applies the Kotlin Gradle Plugin instead of Flutter's future Built-in Kotlin path. `flutter pub outdated` confirms TagVerity's direct dependencies are currently up to date. This is an upstream future-compatibility warning, not a current build failure.
## iOS
- Core NFC presents the system scan sheet; TagVerity cannot provide Android-style silent continuous polling.
- Polling covers ISO 14443 and ISO 15693.
- NFC-F polling is intentionally scoped to the NFC Forum Type 3 / NDEF system code `12FC`, which is declared in `Info.plist`. TagVerity does not enumerate proprietary FeliCa system codes.
- Continuous Batch rearms by opening a new Core NFC session, so the system sheet may reopen between tags.
- iOS may expose fewer identifiers and protocol fields than Android. When no comparable identifier is exposed, TagVerity marks identity as session-only and skips repeated-ID comparison.
- Missing UID or optional metadata does not mean a physical tag is empty or defective.
- A real iPhone, valid signing Team, NFC Tag Reading entitlement, and usage description are required for hardware validation.
## Assessment meaning
- **PASS**: the core read completed with no inspection warnings. NDEF is not required.
- **LIMITED**: the tag was read, but a user-disabled read option prevents a complete optional inspection (currently NDEF content reading).
- **REVIEW**: one or more core reads failed or the OS exposed no usable technology stack.
These labels are inspection summaries, not authenticity or security guarantees.
## Troubleshooting order
1. Confirm NFC works with a known standard NDEF test tag.
2. Move the tag around the phone antenna area and keep it still briefly.
3. Check TagVerity diagnostics.
4. Test the same tag on another NFC-capable device if possible.
5. Separate phone compatibility issues from tag-specific behavior before treating a tag as defective.
