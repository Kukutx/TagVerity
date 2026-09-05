$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
dart format --output=none --set-exit-if-changed lib test tool
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
dart run tool/validate_project.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter analyze
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
