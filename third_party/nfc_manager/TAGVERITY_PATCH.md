# TagVerity nfc_manager compatibility patch

TagVerity vendors `nfc_manager` 4.2.1 temporarily so Android can use AGP 9 Built-in Kotlin without relying on Flutter's legacy KGP compatibility flag.

Upstream source: https://github.com/okadan/flutter-nfc-manager
Upstream package: https://pub.dev/packages/nfc_manager/versions/4.2.1
Upstream license: MIT (`LICENSE` is preserved in this directory).

Local changes are intentionally limited to Android build metadata and the minimum SDK declarations required by Flutter's Built-in Kotlin migration guidance:

- the Android plugin no longer applies `kotlin-android` / `org.jetbrains.kotlin.android`;
- Kotlin compilation uses `KotlinAndroidProjectExtension.compilerOptions` with JVM 17;
- the Android buildscript uses AGP 9.1.0 and KGP 2.4.0, matching TagVerity's Android toolchain;
- the vendored package requires Flutter >= 3.44 / Dart >= 3.12, while TagVerity itself already requires Flutter >= 3.47.1 / Dart >= 3.13.1.

The Dart, Android runtime, and iOS runtime source from upstream 4.2.1 is otherwise unchanged.

Related upstream tracking:

- https://github.com/okadan/flutter-nfc-manager/issues/276
- https://github.com/okadan/flutter-nfc-manager/pull/277

When an official `nfc_manager` release includes Built-in Kotlin support, remove this directory and the `dependency_overrides` entry after the normal analyze/test/Android/iOS build gates pass.
