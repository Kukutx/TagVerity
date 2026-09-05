# Android release signing
TagVerity uses a private Google Play upload key for release builds.
## Current maintainer machine
A local upload key is expected at:
- `android/upload-keystore.jks`
- `android/key.properties`
Both files are excluded by `.gitignore` and must never be committed or shared publicly.
**Back up both files together before the first Google Play upload.** Google Play App Signing should manage the final app-signing key while this local key remains the upload key.
## Build a signed Google Play bundle
```powershell
.\scripts\build_store_android.ps1
```
On the maintainer Windows machine this script also enforces:
- exact Flutter 3.47.1 / Dart 3.13.1;
- the maintainer's one-SDK-on-PATH policy;
- presence of the private upload keystore configuration.
The open-source project itself does **not** require contributors to keep only one Flutter SDK installed.
The store script builds Flutter runtimes for:
- `android-arm` (32-bit ARM);
- `android-arm64` (64-bit ARM).
The bundle is created at:
```text
build/app/outputs/bundle/release/app-release.aab
```
The Android application ID is:
```text
dev.kukutx.tagverity
```
For a lighter local development/release APK, `scripts/build_android.ps1` remains ARM64-only.
## Moving to another development machine
Restore `android/upload-keystore.jks` and `android/key.properties` from the private backup. Do not place passwords in source code, documentation, CI logs, issue comments, or public secrets.
