#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/validate_project.dart
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info 75
