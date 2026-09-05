# Physical device test checklist
This checklist is the final v1.0 gate that automated tests cannot replace. Software validation does not require an emulator; the items below require real NFC hardware and, for iOS, a signed build.
## Before testing
- [ ] Maintainer release machine passes `setup.ps1 --strict-sdk --single-sdk` (Flutter 3.47.1 / Dart 3.13.1).
- [ ] Android/iOS platform projects are committed and configured.
- [ ] NFC is enabled on the device.
- [ ] Use at least one known standard NDEF tag for a baseline.
- [ ] If available, prepare one NFC-V / ISO 15693 tag and one NFC-F / Type 3 tag.
## Inspect
- [ ] App reports NFC availability correctly.
- [ ] Start/stop scan works repeatedly.
- [ ] A known tag is detected before the fixed 30-second timeout.
- [ ] Technology list is displayed.
- [ ] UID / comparable identifier appears when the platform exposes one.
- [ ] Standard NDEF Text and URI records decode correctly.
- [ ] An empty NDEF tag is reported as empty, not defective.
- [ ] A valid non-NDEF smart card can PASS when the core read succeeds.
- [ ] Disabling NDEF reading produces LIMITED with the correct explanation.
- [ ] A real NDEF read failure produces REVIEW.
- [ ] App returns cleanly from background/foreground changes and refreshes NFC availability.
## NFC family coverage
### NFC-A / NFC-B / ISO 14443
- [ ] Read a known NFC-A tag.
- [ ] Read an NFC-B tag if available.
- [ ] Read an ISO-DEP smart card if available without claiming its proprietary application or validity.
### NFC-V / ISO 15693
- [ ] Android detects and labels an NFC-V tag.
- [ ] Android shows public NFC-V metadata where the controller exposes it.
- [ ] iPhone detects and labels an ISO 15693 tag.
- [ ] Missing optional metadata does not force REVIEW.
### NFC-F / ISO 18092
- [ ] Android detects and labels an NFC-F / FeliCa-compatible tag if available.
- [ ] Android exposes public system/manufacturer metadata when available.
- [ ] iPhone recognizes an NFC Forum Type 3 / NDEF tag using system code `12FC` if available.
- [ ] TagVerity does not claim support for arbitrary proprietary FeliCa system codes on iPhone.
## Batch
- [ ] Start a continuous batch and scan at least five tags without pressing Scan between successful reads.
- [ ] Confirm the next session rearms after the previous native session closes; no artificial timing delay is visible.
- [ ] Stop continuous mode and confirm no additional scans are armed.
- [ ] Start a manual batch and confirm one-tag-at-a-time scanning still works.
- [ ] Scan count increments once per successful read.
- [ ] Re-scan a tag with a comparable identifier and confirm the repeated ID is highlighted.
- [ ] On a session-only identity, confirm repeated-ID comparison is reported unavailable rather than claiming uniqueness.
- [ ] Finish batch while scanning and confirm the active scan stops without losing completed results.
- [ ] Batch CSV contains identity stability plus `unknown` repeated-ID status for session-only identities.
- [ ] Scroll a large batch smoothly enough that lazy result rendering is evident.
- [ ] Clear batch removes the in-memory result.
## History & privacy
- [ ] New history entries omit raw UID by default.
- [ ] New history entries omit NDEF content by default.
- [ ] Linkable technical fields are removed by default.
- [ ] Enabling each sensitive retention setting works only after confirmation.
- [ ] Turning a sensitive retention setting off removes the matching already-saved data.
- [ ] “Remove sensitive saved data” clears raw UID, retained NDEF, and linkable technical identifiers together.
- [ ] Search finds entries by technology/fingerprint/content that is actually retained.
- [ ] Swipe-to-delete only removes a row after persistence succeeds.
- [ ] Clear-history success is reported only after persistence succeeds.
- [ ] A deliberately corrupted local history/settings fixture surfaces an error rather than silently looking empty (developer test only).
## Error and export UX
- [ ] Trigger an NFC error from Inspect and confirm the global error banner appears.
- [ ] Trigger an error from Batch/History/Settings and confirm the banner is visible without switching to Inspect.
- [ ] Dismiss the global error banner successfully.
- [ ] Share scan JSON, history JSON, and batch CSV through the system share sheet.
- [ ] Repeated exports do not accumulate old `tagverity-*` temporary files indefinitely.
## Android
- [ ] Test on at least two NFC-capable Android phones if available.
- [ ] Confirm app resumes after scan timeout.
- [ ] Confirm no crash if MIFARE Classic or optional low-level metadata is unsupported by the phone.
- [ ] Confirm release AAB installs correctly through an internal/test track after signing.
## iOS
- [ ] NFC system sheet appears correctly.
- [ ] Successful scan closes with success feedback.
- [ ] Cancellation/session errors return to a usable app state.
- [ ] Continuous batch mode rearms by reopening the system sheet rather than pretending iOS supports silent polling.
- [ ] ISO 15693 works on a physical iPhone when a test tag is available.
- [ ] Type 3 / `12FC` NFC-F works when a matching tag is available.
- [ ] Signed Xcode Archive succeeds with the NFC entitlement and usage description.
## Regression / safety boundary
- [ ] No tag-writing UI exists.
- [ ] No card-emulation UI exists.
- [ ] No arbitrary APDU/transceive UI exists.
- [ ] No network request occurs during normal use.
- [ ] PASS / LIMITED / REVIEW never claims authenticity, ownership, authorization, balance, or proprietary-card validity.
