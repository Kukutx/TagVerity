# TagVerity: NFC Inspector
TagVerity is a privacy-first, read-only NFC inspection app for Android and iOS. It focuses on reliable real-world tag checking rather than card cloning or protocol experimentation.
## What it does
- Inspect NFC-A / NFC-B (ISO 14443), NFC-V (ISO 15693), and NFC-F (ISO 18092) tags exposed by the phone.
- Show public tag technology, a platform-exposed UID/identifier when available, standard NDEF, and public protocol metadata.
- Summarize each scan as **PASS**, **LIMITED**, or **REVIEW** without treating “no NDEF” as a tag failure.
- Run manual or continuous batch checks and flag repeated comparable identifiers when the platform exposes one.
- Search privacy-minimized local history.
- Copy or share scan/history JSON (schema v3) and batch CSV reports.
- Work offline with no account, ads, analytics, telemetry, or background upload.
On iPhone, NFC-F polling is intentionally limited to the NFC Forum Type 3 / NDEF system code `12FC`; TagVerity does not enumerate proprietary FeliCa systems.
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
Project compatibility baseline:
- Flutter **>= 3.47.1**
- Dart **>= 3.13.1**
- Android minSdk **24**
- iOS minimum **13.0**
CI is pinned to Flutter **3.47.1 / Dart 3.13.1** for reproducibility. The maintainer machine can additionally enforce its one-SDK policy with:
```powershell
.\setup.ps1 --strict-sdk --single-sdk
```
That one-SDK check is a local maintainer policy, not a requirement for open-source contributors.
## Run and validate without an emulator
```bash
flutter pub get
dart run tool/validate_project.dart
flutter analyze
flutter test
flutter build apk --debug
```
GitHub Actions also compiles iOS with `flutter build ios --debug --no-codesign`. A simulator is not required for these checks. Physical NFC hardware is required only for RF/tag compatibility validation.
## Store build
Windows maintainer build using the private upload key:
```powershell
.\scripts\build_store_android.ps1
```
The store script builds ARM32 + ARM64 AAB coverage. See `docs/ANDROID_SIGNING.md`. For iOS, use Xcode signing and Archive on macOS.
## Structure
```text
lib/
  core/                 constants, theme, small utilities
  domain/               models, assessment, classification, reports, privacy rules
  data/export/          native report sharing
  data/nfc/             read-only NFC adapter
  data/storage/         local settings/history storage
  presentation/         Inspect, Batch, History, Settings UI
test/                    unit, controller, and widget tests
docs/                    privacy, platform, signing, roadmap, and release notes
assets/branding/         TagVerity logo and app-icon sources
```
## Privacy defaults
By default, saved history does **not** retain:
- raw UID;
- NDEF payload content;
- selected linkable technical identifiers.
A SHA-256 fingerprint derived from an OS-exposed identifier is still pseudonymous and may correlate scans. If the OS exposes no comparable identifier, TagVerity marks the scan as session-only and skips repeated-ID checks.
Turning a sensitive retention setting off also removes the matching saved data from existing history before the setting change is committed.
See `docs/PRIVACY_MODEL.md` for the full model.
## Product focus
TagVerity 1.0 focuses on three jobs:
1. **NFC Inspector** — understand one tag.
2. **Tag Checker** — see whether the read looks normal or needs review.
3. **Batch Scan** — inspect a set of tags and spot repeated comparable IDs or warnings.
## Open source
TagVerity is developed under the MIT license. Core reliability comes before feature count.
- See `docs/ROADMAP.md` for the core-first plan.
- See `CONTRIBUTING.md` before proposing changes.
- Use GitHub Issues for reproducible bugs and feature requests.
- Report security-sensitive issues through `SECURITY.md`, not a public issue.
## Release gate
Software validation can run without an emulator. The final v1.0 gate is the physical-device matrix in `docs/DEVICE_TEST_CHECKLIST.md`, plus a signed iOS Archive.
## License
MIT. See `LICENSE`.
