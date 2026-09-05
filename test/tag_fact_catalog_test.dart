import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/domain/models/tag_fact_catalog.dart';

void main() {
  test('privacy scrub removes linkable technical values', () {
    final Map<String, String> scrubbed = TagFactCatalog.privacyScrubbedDetails(
      const <String, String>{
        'nfca.sak': '0x00',
        'barcode.value': 'AA:BB:CC',
        'nfcf.manufacturer': '01:02:03:04:05:06:07:08',
        'isodep.historicalBytes': '01:02:03',
        'future.unknownSensitiveField': 'private-value',
      },
    );

    expect(scrubbed['nfca.sak'], '0x00');
    expect(scrubbed.containsKey('barcode.value'), isFalse);
    expect(scrubbed.containsKey('nfcf.manufacturer'), isFalse);
    expect(scrubbed.containsKey('isodep.historicalBytes'), isFalse);
    expect(scrubbed.containsKey('future.unknownSensitiveField'), isFalse);
  });

  test('opt-in retention still drops unknown technical fields', () {
    final Map<String, String> retained = TagFactCatalog.historyRetainedDetails(
      const <String, String>{
        'nfca.sak': '0x00',
        'barcode.value': 'AA:BB:CC',
        'future.unknownSensitiveField': 'private-value',
      },
      includeLinkable: true,
    );

    expect(retained['nfca.sak'], '0x00');
    expect(retained['barcode.value'], 'AA:BB:CC');
    expect(retained.containsKey('future.unknownSensitiveField'), isFalse);
  });
}
