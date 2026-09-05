#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/validate_project.dart
flutter analyze
flutter test
