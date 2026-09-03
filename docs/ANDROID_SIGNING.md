# Android release signing

TagVerity uses a private Google Play upload key for release builds.

## Current development machine

A local upload key has been generated at:

- `android/upload-keystore.jks`
- `android/key.properties`

Both files are excluded by `.gitignore` and must never be committed or shared publicly.

**Back up both files together before the first Google Play upload.** After an app has been published, do not casually regenerate the upload key. Google Play App Signing should be enabled in Play Console so Google manages the final app-signing key while this local key remains the upload key.

## Build a signed Google Play bundle

```powershell
.\scripts\build_store_android.ps1
```

The verified bundle is created at:

```text
build/app/outputs/bundle/release/app-release.aab
```

The Android application ID is:

```text
dev.kukutx.tagverity
```

## Moving to another development machine

Restore `android/upload-keystore.jks` and `android/key.properties` from the private backup. Do not place the password in source code, documentation, CI logs, or public secrets.
