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

- [ ] Start a batch and scan at least five tags.
- [ ] Scan count increments once per successful read.
- [ ] Re-scan one tag and confirm duplicate detection.
- [ ] Finish batch without losing results.
- [ ] Batch CSV copies correctly.
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
- [ ] iOS-limited metadata is shown as limited rather than falsely reported as failure.

## Regression

- [ ] No tag writing UI exists.
- [ ] No card emulation UI exists.
- [ ] No arbitrary APDU/transceive UI exists.
- [ ] No network request occurs during normal use.
