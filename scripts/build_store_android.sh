#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -f android/key.properties ]]; then
  echo "Missing android/key.properties. Configure the private Google Play upload key first; see docs/ANDROID_SIGNING.md." >&2
  exit 1
fi
if [[ ! -f android/upload-keystore.jks ]]; then
  echo "Missing android/upload-keystore.jks. Restore the private upload keystore backup first." >&2
  exit 1
fi
dart run tool/bootstrap.dart
flutter build appbundle --release --target-platform android-arm,android-arm64
