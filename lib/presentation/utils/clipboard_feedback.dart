import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class ClipboardFeedback {
  static Future<bool> copy(
    BuildContext context,
    String text, {
    String successMessage = 'Copied to clipboard',
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      }
      return true;
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not copy to clipboard')),
        );
      }
      return false;
    }
  }
}
