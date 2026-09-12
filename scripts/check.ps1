$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
dart format --output=none --set-exit-if-changed lib test tool
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
dart run tool/validate_project.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter analyze
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter test --coverage
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
dart run tool/check_coverage.dart coverage/lcov.info 75
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
