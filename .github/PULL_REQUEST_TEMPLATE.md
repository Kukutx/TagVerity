## What changed

Describe the user-visible or maintenance problem this pull request solves.

## Core-first check

- [ ] This change improves or preserves TagVerity's core NFC inspection workflow.
- [ ] It stays inside the read-only safety boundary.
- [ ] It does not make unsupported claims about tag identity, authenticity, or proprietary systems.
- [ ] Privacy-minimized defaults are preserved.

## Validation

- [ ] `dart format --output=none --set-exit-if-changed lib test tool`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] Android build succeeds when Android code/config changed.
- [ ] Physical NFC testing completed when NFC behavior changed, using `docs/DEVICE_TEST_CHECKLIST.md`.

## Privacy / compatibility notes

List any changes to stored data, exported data, platform permissions, minimum versions, or existing JSON fields. Write `None` if not applicable.
