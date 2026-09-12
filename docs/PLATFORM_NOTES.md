# Platform notes
## Android
- Polling covers NFC-A / NFC-B (`ISO 14443`), NFC-V (`ISO 15693`), and NFC-F (`ISO 18092`).
- Continuous Batch starts a new reader session only after the previous native session has closed; there is no timing-based rearm delay.
- Native session start and close waits are each bounded to 5 seconds for UI recovery, while the fixed 30-second scan timeout stays active through tag inspection. Timeout or Stop never assumes an unresolved native start was canceled: replacement sessions remain blocked, a late successful start is automatically closed, and the lock stays held through that cleanup close. Likewise, an unconfirmed close suppresses scan success/rearm until the outstanding close settles.
- Android generally exposes more low-level NFC metadata than iOS.
- Optional controller metadata such as timeout/max-transceive values is best-effort and does not make an otherwise healthy tag fail assessment.
- UID and technology availability depend on the phone NFC controller and Android stack.
- MIFARE Classic support is hardware-dependent; TagVerity reports only what the phone exposes.
- Antenna position varies by device. Thick cases, metal accessories, or multiple contactless cards can reduce read reliability.
### Current Flutter/Kotlin compatibility note
TagVerity uses the upstream `nfc_manager` 4.2.1 runtime source with a reviewed local Android build-metadata patch so AGP 9 runs with Flutter Built-in Kotlin instead of applying the legacy Kotlin Gradle Plugin. The local override keeps the upstream MIT license and is guarded by `tool/validate_project.dart`. Remove it once an official `nfc_manager` release includes Built-in Kotlin support and the normal analyze/test/Android/iOS build gates pass. Upstream tracking: `okadan/flutter-nfc-manager#276` and PR `#277`.
## iOS
- Core NFC presents the system scan sheet; TagVerity cannot provide Android-style silent continuous polling.
- Polling covers ISO 14443 and ISO 15693.
- Standard NFC Forum Type 4 / NDEF ISO 7816 selection is enabled with AID `D2760000850101`. TagVerity does not claim arbitrary ISO 7816 application discovery on iOS because Core NFC requires declared AIDs.
- NFC-F polling is intentionally scoped to the NFC Forum Type 3 / NDEF system code `12FC`, which is declared in `Info.plist`. TagVerity does not enumerate proprietary FeliCa system codes.
- Continuous Batch rearms by opening a new Core NFC session, so the system sheet may reopen between tags.
- iOS may expose fewer identifiers and protocol fields than Android. When no comparable identifier is exposed, TagVerity marks identity as session-only and skips repeated-ID comparison.
- Missing UID or optional metadata does not mean a physical tag is empty or defective.
- A real iPhone, valid signing Team, NFC Tag Reading entitlement, and usage description are required for hardware validation.
## Assessment meaning
- **PASS**: the core read completed with no inspection warnings. NDEF is not required.
- **LIMITED**: the tag was read, but optional inspection data is incomplete because a read option is disabled or the OS did not expose/record optional metadata such as the technology stack or NDEF status.
- **REVIEW**: one or more actual inspection reads failed or explicit scan warnings were produced.
These labels are inspection summaries, not authenticity or security guarantees.
## Troubleshooting order
1. Confirm NFC works with a known standard NDEF test tag.
2. Move the tag around the phone antenna area and keep it still briefly.
3. Check TagVerity diagnostics.
4. Test the same tag on another NFC-capable device if possible.
5. Separate phone compatibility issues from tag-specific behavior before treating a tag as defective.
