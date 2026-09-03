# Release checklist

## Toolchain

- [ ] `where flutter` resolves only to the intended Flutter SDK.
- [ ] Flutter is 3.47.1 and Dart is 3.13.1.
- [ ] `flutter pub get` succeeds.
- [ ] `dart format --output=none --set-exit-if-changed lib test tool` succeeds.
- [ ] `flutter analyze` reports no issues.
- [ ] `flutter test` passes.

## Product

- [ ] Inspect flow reads a known NFC/NDEF test tag.
- [ ] PASS / LIMITED / REVIEW assessment is sensible on real tags.
- [ ] Batch mode records multiple tags.
- [ ] Duplicate tags are detected within a batch.
- [ ] History search works.
- [ ] JSON and batch CSV exports work.
- [ ] Raw UID, NDEF, and linkable technical history are off by default.

## Android

- [ ] NFC permission and NFC hardware feature are declared.
- [ ] Application label is `TagVerity`.
- [ ] Package/application ID is final.
- [ ] Release signing is configured outside the repository.
- [ ] `flutter build appbundle --release` succeeds.
- [ ] Test on at least two NFC-capable Android devices if available.

## iOS

- [ ] NFCReaderUsageDescription is present.
- [ ] NFC Tag Reading entitlement is enabled.
- [ ] Bundle identifier is final.
- [ ] Signing Team is configured in Xcode.
- [ ] Archive succeeds on macOS.
- [ ] Physical iPhone NFC validation passes.

## Store assets

- [ ] Final app icon and logo are exported at required sizes.
- [ ] Screenshots match the current UI.
- [ ] App description does not claim cloning, authentication, or proprietary card validity.
- [ ] Privacy disclosures match the offline/no-telemetry implementation.
- [ ] Support URL and privacy-policy URL are configured before submission.
