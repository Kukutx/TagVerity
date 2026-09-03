$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

dart run tool/bootstrap.dart
flutter build apk --release --target-platform android-arm64
