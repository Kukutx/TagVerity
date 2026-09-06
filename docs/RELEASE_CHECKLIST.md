# Release checklist
## Toolchain and automated validation
- [ ] Flutter is compatible with the project baseline (>= 3.47.1) and Dart >= 3.13.1.
- [ ] Maintainer release machine: `setup.ps1 --strict-sdk --single-sdk` passes, enforcing Flutter 3.47.1 / Dart 3.13.1 from the intended single SDK.
- [ ] `flutter pub get` succeeds.
- [ ] `dart format --output=none --set-exit-if-changed lib test tool` succeeds.
- [ ] `dart run tool/validate_project.dart` succeeds.
- [ ] `flutter analyze` reports no issues.
- [ ] `flutter test` passes, including Widget Tests.
- [ ] GitHub Actions completes formatting, metadata/schema validation, tests, Android debug build, unsigned ARM32+ARM64 release AAB build with ABI verification, and unsigned iOS release compile.
## Product
- [ ] Inspect flow reads known ISO 14443 / NFC-A or NFC-B tags.
- [ ] NFC-V / ISO 15693 reads on representative hardware.
- [ ] NFC-F reads on Android; NFC Forum Type 3 (`12FC`) reads on iPhone when hardware is available.
- [ ] A standard NFC Forum Type 4 / NDEF tag reads on iPhone through declared AID `D2760000850101`; no arbitrary ISO 7816 application support is claimed.
- [ ] PASS / LIMITED / REVIEW semantics are sensible on real tags; a valid non-NDEF smart card can PASS.
- [ ] Manual and continuous Batch modes both record multiple tags.
- [ ] Continuous Batch stops cleanly on user stop, scan error/timeout, batch finish, app backgrounding, and capacity limit.
- [ ] Repeated IDs are flagged only when a comparable platform identifier is available; session-only scans remain explicitly not comparable.
- [ ] History search and transactional delete/clear behavior work.
- [ ] JSON schema-v3 and identity-aware batch CSV exports work.
- [ ] Share failures produce the global error banner rather than crashing.
- [ ] Raw UID, NDEF, and linkable technical history are off by default.
- [ ] Disabling sensitive retention immediately stops future retention and removes matching already-saved data.
- [ ] If historical cleanup fails after disabling retention, the setting stays off, sensitive data remains hidden in the running UI/export path, and the global error banner reports incomplete on-disk cleanup.
- [ ] Scan-save, delete, clear, and privacy-history mutations remain serialized under rapid user actions.
- [ ] If saved privacy settings are unreadable, history remains hidden/untouched and scanning is blocked until an explicit recovery applies the complete current privacy policy; interim toggle changes do not load or rewrite history.
## Android
- [ ] NFC permission and NFC hardware feature are declared.
- [ ] Application label is `TagVerity`.
- [ ] Package/application ID is final.
- [ ] Release signing is configured outside the repository.
- [ ] Store AAB builds ARM32 + ARM64 successfully.
- [ ] Test on at least two NFC-capable Android devices if available.
## iOS
- [ ] `NFCReaderUsageDescription` is present.
- [ ] NFC Tag Reading entitlement is enabled.
- [ ] NFC Forum Type 3 FeliCa system code `12FC` is present in `Info.plist`.
- [ ] NFC Forum Type 4 / NDEF ISO 7816 AID `D2760000850101` is present in `Info.plist`.
- [ ] Bundle identifier is final.
- [ ] Signing Team is configured in Xcode.
- [ ] Archive succeeds on macOS.
- [ ] Physical iPhone NFC validation passes.
## Store assets
- [ ] Final app icon and logo are exported at required sizes.
- [ ] Screenshots match the current simplified Settings and detail UI.
- [ ] App description says “possible repeated IDs” rather than claiming identity proof.
- [ ] App description does not claim cloning, authentication, or proprietary card validity.
- [ ] Privacy disclosures match the offline/no-telemetry implementation.
- [ ] Support URL and privacy-policy URL are configured before submission.
