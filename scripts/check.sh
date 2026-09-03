#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
dart format lib test tool
flutter analyze
flutter test
