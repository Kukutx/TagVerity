# TagVerity validation report

Validation date: 2026-09-03  
Version: 1.0.0+1

## Status

TagVerity has been converted from the former transport-card inspector prototype into a general-purpose NFC Inspector / Tag Checker / Batch Scanner product.

### Verified on this Windows development machine

- Flutter 3.47.1 / Dart 3.13.1 from the single configured Flutter SDK.
- `flutter analyze`: **0 issues**.
- `flutter test`: **16/16 passed**.
- Android Kotlin release compilation: passed.
- Signed Android release APK: passed.
- Signed Google Play AAB: passed.
- APK signature verification: passed with APK Signature Scheme v2.
- AAB JAR signature verification: passed.
- Android application ID: `dev.kukutx.tagverity`.
- Version: `1.0.0+1`.
- Android minSdk: 24.
- Android targetSdk: 36.
- Android compileSdk: 36.
- App label: `TagVerity`.
- NFC permission and required NFC hardware feature are present.
- Private upload keystore and `key.properties` are excluded by `.gitignore`.

## Release artifacts

Local release copies are stored under `dist/`:

- `TagVerity-1.0.0-arm64.apk` — 18,151,914 bytes
- `TagVerity-1.0.0-arm64.aab` — 18,222,476 bytes

SHA-256:

```text
a655dab8c0b5ddbd018b4e64efae4535e2051cc818a82c18f7835d7987ec40e6  TagVerity-1.0.0-arm64.apk
f0cf59c23d5273fddaa7812265289c6e1bb8f5cfbd14f0d37fa0199b7aaf514b  TagVerity-1.0.0-arm64.aab
```

## Product capabilities verified in code/tests

- Single NFC inspection flow.
- PASS / LIMITED / REVIEW tag assessment.
- Batch scan session.
- Duplicate fingerprint detection.
- Searchable local history.
- Privacy-scrubbed history defaults.
- NDEF decoding.
- JSON export and batch CSV generation.
- Native Android report sharing compiled in release mode.
- Android/iOS app icons and TagVerity branding assets present.

## Platform notes

Android release builds are currently produced for the `arm64` Flutter runtime to keep builds reliable on this 16 GB development machine. The APK may also contain small auxiliary native libraries for other ABIs from dependencies; the Flutter runtime itself is arm64.

iOS project files, NFC entitlement, usage description, branding, and native report-sharing code are prepared. A real iOS Archive cannot be produced or signed on Windows; final iOS validation requires macOS/Xcode, an Apple signing Team, and an NFC-capable iPhone.

## Remaining real-world release checks

These cannot be truthfully completed without external hardware/store accounts:

- Physical Android NFC scan regression on representative tags.
- Physical iPhone NFC regression and Xcode Archive.
- Google Play Console upload, store screenshots, support URL, and privacy-policy URL.
- App Store Connect upload and review metadata.

## Known toolchain warning

Flutter 3.47.1 reports that the current `nfc_manager` plugin still applies the Kotlin Gradle Plugin directly and will need migration to Flutter's future Built-in Kotlin model. The dependency is currently the latest resolvable direct dependency for this project and Android release builds succeed today. Recheck this warning on future Flutter upgrades.
