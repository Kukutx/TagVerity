import 'package:flutter/services.dart';

abstract final class ErrorText {
  static String clean(Object error) {
    if (error is PlatformException) {
      final String message = error.message?.trim() ?? '';
      return message.isEmpty ? error.code.trim() : message;
    }
    if (error is FormatException) {
      return error.message.toString().trim();
    }
    if (error is StateError) {
      return error.message.trim();
    }
    return error
        .toString()
        .replaceFirst(
          RegExp(r'^(Exception:|Bad state:|FormatException:)\s*'),
          '',
        )
        .trim();
  }
}
