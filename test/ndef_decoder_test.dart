import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:tagverity/core/utils/ndef_decoder.dart';

void main() {
  group('NdefDecoder', () {
    test('decodes a well-known UTF-8 text record', () {
      final NdefRecord record = _record(
        type: 'T',
        payload: <int>[0x02, ...ascii.encode('en'), ...utf8.encode('Hello')],
      );

      final result = NdefDecoder.decodeRecord(0, record);

      expect(result.summary, 'Hello [en]');
    });

    test('decodes UTF-16 big-endian text with BOM', () {
      final NdefRecord record = _record(
        type: 'T',
        payload: <int>[
          0x82,
          ...ascii.encode('en'),
          0xFE,
          0xFF,
          0x00,
          0x48,
          0x00,
          0x69,
        ],
      );

      expect(NdefDecoder.decodeRecord(0, record).summary, 'Hi [en]');
    });

    test('decodes UTF-16 little-endian text with BOM', () {
      final NdefRecord record = _record(
        type: 'T',
        payload: <int>[
          0x82,
          ...ascii.encode('en'),
          0xFF,
          0xFE,
          0x48,
          0x00,
          0x69,
          0x00,
        ],
      );

      expect(NdefDecoder.decodeRecord(0, record).summary, 'Hi [en]');
    });

    test('rejects malformed UTF-8 text', () {
      final NdefRecord record = _record(
        type: 'T',
        payload: <int>[0x02, ...ascii.encode('en'), 0xC3, 0x28],
      );

      expect(
        NdefDecoder.decodeRecord(0, record).summary,
        'Invalid UTF-8 text record',
      );
    });

    test('rejects invalid text language length', () {
      final NdefRecord record = _record(type: 'T', payload: <int>[0x3F, 0x65]);

      expect(NdefDecoder.decodeRecord(0, record).summary, 'Invalid text record');
    });

    test('decodes a compressed URI record', () {
      final NdefRecord record = _record(
        type: 'U',
        payload: <int>[0x04, ...utf8.encode('example.com')],
      );

      expect(NdefDecoder.decodeRecord(0, record).summary, 'https://example.com');
    });

    test('supports the complete NFC Forum URI prefix range', () {
      final NdefRecord record = _record(
        type: 'U',
        payload: <int>[0x23, ...utf8.encode('wkt:example')],
      );

      expect(
        NdefDecoder.decodeRecord(0, record).summary,
        'urn:nfc:wkt:example',
      );
    });

    test('reports unknown URI prefix instead of dropping it', () {
      final NdefRecord record = _record(
        type: 'U',
        payload: <int>[0x24, ...utf8.encode('example')],
      );

      expect(
        NdefDecoder.decodeRecord(0, record).summary,
        'URI with unknown prefix 0x24: example',
      );
    });

    test('caps long summaries', () {
      final NdefRecord record = NdefRecord(
        typeNameFormat: TypeNameFormat.media,
        type: Uint8List.fromList(ascii.encode('text/plain')),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(utf8.encode('a' * 400)),
      );

      final String summary = NdefDecoder.decodeRecord(0, record).summary;

      expect(summary.runes.length, NdefDecoder.maximumSummaryCharacters + 1);
      expect(summary.endsWith('…'), isTrue);
    });

    test('does not present binary media as text', () {
      final NdefRecord record = NdefRecord(
        typeNameFormat: TypeNameFormat.media,
        type: Uint8List.fromList(ascii.encode('application/octet-stream')),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(<int>[0, 1, 2, 3]),
      );

      expect(
        NdefDecoder.decodeRecord(0, record).summary,
        'Media record: application/octet-stream (4 bytes)',
      );
    });
  });
}

NdefRecord _record({required String type, required List<int> payload}) {
  return NdefRecord(
    typeNameFormat: TypeNameFormat.wellKnown,
    type: Uint8List.fromList(ascii.encode(type)),
    identifier: Uint8List(0),
    payload: Uint8List.fromList(payload),
  );
}
