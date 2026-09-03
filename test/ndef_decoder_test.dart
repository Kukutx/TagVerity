import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:tagverity/core/utils/ndef_decoder.dart';

void main() {
  group('NdefDecoder', () {
    test('decodes a well-known UTF-8 text record', () {
      final NdefRecord record = NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList(ascii.encode('T')),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(<int>[
          0x02,
          ...ascii.encode('en'),
          ...utf8.encode('Hello'),
        ]),
      );
      final NdefMessage message = NdefMessage(records: <NdefRecord>[record]);

      final result = NdefDecoder.decodeMessage(message);

      expect(result, hasLength(1));
      expect(result.single.type, 'T');
      expect(result.single.summary, 'Hello [en]');
    });

    test('decodes a compressed URI record', () {
      final NdefRecord record = NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList(ascii.encode('U')),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(<int>[0x04, ...utf8.encode('example.com')]),
      );

      final result = NdefDecoder.decodeRecord(0, record);

      expect(result.summary, 'https://example.com');
    });

    test('supports the complete NFC Forum URI prefix range', () {
      final NdefRecord record = NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList(ascii.encode('U')),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(<int>[0x23, ...utf8.encode('wkt:example')]),
      );

      final result = NdefDecoder.decodeRecord(0, record);

      expect(result.summary, 'urn:nfc:wkt:example');
    });
  });
}
