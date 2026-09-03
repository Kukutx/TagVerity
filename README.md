# TagVerity: NFC Inspector

TagVerity is a privacy-first, read-only NFC inspection app for Android and iOS. It is designed for real-world tag checking rather than card cloning or protocol experimentation.

## What it does

- Inspect ISO 14443 NFC tags and cards.
- Show public tag technology, UID when exposed by the OS, standard NDEF, and public protocol metadata.
- Automatically summarize each scan as **PASS**, **LIMITED**, or **REVIEW**.
- Run batch checks and detect duplicate tag fingerprints within the batch.
- Search local scan history.
- Copy or share scan/history JSON and batch CSV reports.
- Minimize stored identifiers by default.
- Work offline with no account, ads, analytics, telemetry, or background upload.

## Safety boundary

TagVerity is intentionally read-only. It does not implement:

- NFC tag writing or formatting;
- card emulation or HCE;
- UID spoofing or cloning;
- MIFARE key recovery or authentication attacks;
- arbitrary APDU/transceive consoles;
- protected page/block extraction;
- replay or relay tooling.

A successful scan only confirms what the phone can read. It does not prove ownership, authenticity, access rights, balance, ticket validity, or authorization in a proprietary system.

## Toolchain

The project is aligned with the single Flutter SDK currently used by the development machine:

- Flutter **3.47.1**
- Dart **3.13.1**
- Android minSdk **24**
- iOS minimum **13.0**

Do not install a second Flutter SDK for this project.

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

A physical NFC-capable Android or iPhone is required for real tag scans.

## Build

Development/release APK:

```bash
flutter build apk --release --target-platform android-arm64
```

Google Play AAB using the private upload key configured on this development machine:

```powershell
.\scripts\build_store_android.ps1
```

See `docs/ANDROID_SIGNING.md`. For iOS, use Xcode signing and Archive on macOS.

## Structure

```text
lib/
  core/                 shared constants, theme, utilities
  domain/               models, tag assessment, privacy rules
  data/export/          native report sharing
  data/nfc/             read-only NFC adapter
  data/storage/         local settings/history storage
  presentation/         Inspect, Batch, History, Settings UI
test/                    unit/controller tests
docs/                    privacy, platform, signing and release notes
assets/branding/          TagVerity logo and app-icon source assets
```

## Privacy defaults

By default, history does **not** retain:

- raw UID;
- NDEF payload content;
- selected linkable technical identifiers.

A SHA-256 fingerprint is still pseudonymous and can correlate the same exposed UID across scans. See `docs/PRIVACY_MODEL.md` for the full model.

## Product focus

TagVerity 1.0 focuses on three jobs:

1. **NFC Inspector** — understand one tag.
2. **Tag Checker** — see whether a basic read looks normal or needs review.
3. **Batch Scan** — inspect a set of tags and spot duplicates or warnings.

The app remains intentionally offline-first and read-only.

## Validation

See `VALIDATION_REPORT.md` for the latest verified toolchain, analyze/test results, platform configuration, and remaining store-release requirements.

## License

MIT. See `LICENSE`.
