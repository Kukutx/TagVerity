#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
dart run tool/bootstrap.dart
flutter build apk --release --target-platform android-arm64
