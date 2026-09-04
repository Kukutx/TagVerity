# Physical device test checklist

## Before testing

- [ ] Flutter 3.47.1 / Dart 3.13.1 are active.
- [ ] Android/iOS platform projects are generated and configured.
- [ ] NFC is enabled on the device.
- [ ] Use at least one known standard NDEF tag for baseline testing.

## Inspect

- [ ] App reports NFC availability correctly.
- [ ] Start/stop scan works repeatedly.
- [ ] A known tag is detected within the configured timeout.
- [ ] Technology list is displayed.
- [ ] UID appears when the platform exposes it.
- [ ] Standard NDEF text/URI records are decoded correctly.
- [ ] Scan assessment appears after the read.
- [ ] App returns cleanly from background/foreground changes.

## Batch

- [ ] Start a continuous batch and scan at least five tags without pressing Scan between successful reads.
- [ ] Stop continuous mode and confirm no additional scans are armed.
- [ ] Start a manual batch and confirm one-tag-at-a-time scanning still works.
- [ ] Scan count increments once per successful read.
- [ ] Re-scan a tag with stable identity and confirm duplicate detection.
- [ ] On a scan where the OS does not expose stable identity, confirm the app marks duplicate comparison unavailable instead of claiming uniqueness.
- [ ] Finish batch while scanning and confirm the active scan stops without losing completed results.
- [ ] Batch CSV copies correctly and includes identity stability plus `unknown` duplicate status for session-only identities.
- [ ] Clear batch removes the in-memory batch result.

## History & privacy

- [ ] New history entries omit raw UID by default.
- [ ] New history entries omit NDEF content by default.
- [ ] Linkable technical fields are removed by default.
- [ ] Enabling each optional retention setting works only after confirmation.
- [ ] Cleanup actions remove already-saved sensitive fields.
- [ ] Search finds entries by technology/fingerprint/content that is actually retained.

## Android

- [ ] Test NFC-A/NDEF tag.
- [ ] Test a non-NDEF ISO 14443 tag if available.
- [ ] Confirm app resumes after scan timeout.
- [ ] Confirm no crash if MIFARE Classic is unsupported by the phone.

## iOS

- [ ] NFC system sheet appears correctly.
- [ ] Successful scan closes with success feedback.
- [ ] Cancellation/session errors return to usable app state.
- [ ] Continuous batch mode rearms by reopening the system NFC sheet rather than pretending iOS supports silent polling.
- [ ] iOS-limited metadata is shown as limited rather than falsely reported as failure.

## Regression

- [ ] No tag writing UI exists.
- [ ] No card emulation UI exists.
- [ ] No arbitrary APDU/transceive UI exists.
- [ ] No network request occurs during normal use.
