$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
dart format lib test tool
flutter analyze
flutter test
