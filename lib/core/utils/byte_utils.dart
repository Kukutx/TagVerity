abstract final class ByteUtils {
  static String hex(
    Iterable<int> bytes, {
    String separator = ':',
    int? maxBytes,
  }) {
    final List<int> allBytes = bytes.toList(growable: false);
    final List<int> values = maxBytes == null
        ? allBytes
        : allBytes.take(maxBytes).toList(growable: false);
    final String result = values
        .map(
          (int byte) =>
              (byte & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase(),
        )
        .join(separator);
    final int total = allBytes.length;
    if (maxBytes != null && total > maxBytes) {
      return '$result… (+${total - maxBytes} bytes)';
    }
    return result;
  }

  static String maskUid(String? value) {
    if (value == null || value.isEmpty) {
      return '未保存';
    }
    final List<String> parts = value.split(':');
    if (parts.length <= 2) {
      return '••:••';
    }
    return '${parts.first}:${List<String>.filled(parts.length - 2, '••').join(':')}:${parts.last}';
  }

  static String shortFingerprint(String value) {
    if (value.length <= 16) {
      return value;
    }
    return '${value.substring(0, 8)}…${value.substring(value.length - 8)}';
  }
}
