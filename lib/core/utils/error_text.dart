abstract final class ErrorText {
  static String clean(Object error) {
    return error
        .toString()
        .replaceFirst(
          RegExp(r'^(Exception|StateError|FormatException):\s*'),
          '',
        )
        .trim();
  }
}
