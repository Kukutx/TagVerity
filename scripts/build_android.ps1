$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
dart run tool/bootstrap.dart --strict-sdk --single-sdk
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter build apk --release --target-platform android-arm64
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
