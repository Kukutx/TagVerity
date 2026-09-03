import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/core/utils/byte_utils.dart';

void main() {
  group('ByteUtils', () {
    test('formats hexadecimal bytes', () {
      expect(ByteUtils.hex(<int>[0, 10, 255]), '00:0A:FF');
    });

    test('masks all middle UID bytes', () {
      expect(ByteUtils.maskUid('04:A1:B2:C3:D4:E5:F6'), '04:••:••:••:••:••:F6');
    });

    test('shortens fingerprints', () {
      const String value = '0123456789abcdef0123456789abcdef';
      expect(ByteUtils.shortFingerprint(value), '01234567…89abcdef');
    });
  });
}
