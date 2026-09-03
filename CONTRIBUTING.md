# Contributing

1. Use the project baseline: Flutter 3.47.1 / Dart 3.13.1.
2. Do not add or require a second Flutter SDK for this project.
3. Keep the default NFC path read-only.
4. Keep platform/plugin objects inside `data/`.
5. Use stable metadata keys; do not make business logic depend on translated UI labels.
6. Preserve privacy-minimized history defaults.
7. Run before submitting changes:

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
```

8. NFC behavior changes require physical Android/iOS validation using `docs/DEVICE_TEST_CHECKLIST.md`.
