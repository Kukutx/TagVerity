import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/domain/models/tag_fact_catalog.dart';

void main() {
  test('privacy scrub removes linkable technical values', () {
    final Map<String, String> scrubbed = TagFactCatalog.privacyScrubbedDetails(
      const <String, String>{
        'nfca.sak': '0x00',
        'barcode.value': 'AA:BB:CC',
        'isodep.historicalBytes': '01:02:03',
      },
    );

    expect(scrubbed['nfca.sak'], '0x00');
    expect(scrubbed.containsKey('barcode.value'), isFalse);
    expect(scrubbed.containsKey('isodep.historicalBytes'), isFalse);
  });
}
