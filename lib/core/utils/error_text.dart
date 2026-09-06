import 'package:flutter/services.dart';

abstract final class ErrorText {
  static const int maximumCharacters = 500;
  static final RegExp _controlCharacters = RegExp(
    r'[\u0000-\u001F\u007F-\u009F]+',
  );
  static final RegExp _whitespace = RegExp(r'\s+');

  static String clean(Object error) {
    final String value;
    if (error is PlatformException) {
      final String message = error.message?.trim() ?? '';
      value = message.isEmpty ? error.code.trim() : message;
    } else if (error is FormatException) {
      value = error.message.toString();
    } else if (error is StateError) {
      value = error.message;
    } else {
      value = error.toString().replaceFirst(
        RegExp(r'^(Exception:|Bad state:|FormatException:)\s*'),
        '',
      );
    }
    return _normalize(value);
  }

  static String _normalize(String value) {
    final String normalized = value
        .replaceAll(_controlCharacters, ' ')
        .replaceAll(_whitespace, ' ')
        .trim();
    if (normalized.isEmpty) {
      return 'Unexpected error.';
    }
    final List<int> runes = normalized.runes.toList(growable: false);
    if (runes.length <= maximumCharacters) {
      return normalized;
    }
    return '${String.fromCharCodes(runes.take(maximumCharacters - 1))}…';
  }
}
