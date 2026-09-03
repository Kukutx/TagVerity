$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Test-Path "android/key.properties")) {
  throw "Missing android/key.properties. Configure the private Google Play upload key first; see docs/ANDROID_SIGNING.md."
}

if (-not (Test-Path "android/upload-keystore.jks")) {
  throw "Missing android/upload-keystore.jks. Restore the private upload keystore backup first."
}

dart run tool/bootstrap.dart
flutter build appbundle --release --target-platform android-arm64
