import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/services/history_privacy.dart';

void main() {
  test('history warning sanitization strips raw platform error payloads', () {
    const List<String> warnings = <String>[
      'Could not read standard NDEF: private@example.com',
      'Could not read iOS MIFARE metadata: 04:AA:BB:CC:DD:EE:FF',
      'NFC-A metadata read failed: secret-controller-message',
      'unexpected private payload text',
    ];

    final List<String> safe = HistoryPrivacy.safeWarnings(warnings);

    expect(safe, const <String>[
      'Could not read standard NDEF.',
      'Could not read optional iOS MIFARE metadata.',
      'Optional NFC metadata read failed.',
      'A scan warning was reported.',
    ]);
    expect(safe.join(' '), isNot(contains('private@example.com')));
    expect(safe.join(' '), isNot(contains('04:AA:BB:CC:DD:EE:FF')));
    expect(safe.join(' '), isNot(contains('secret-controller-message')));
    expect(HistoryPrivacy.warningsNeedScrub(warnings), isTrue);
    expect(HistoryPrivacy.warningsNeedScrub(safe), isFalse);
  });

  test('legacy linkable event IDs are replaced before history retention', () {
    final NfcScan scan = NfcScan(
      id: '1780000000000000-abcdef123456',
      scannedAt: DateTime.fromMicrosecondsSinceEpoch(
        1780000000000000,
        isUtc: true,
      ),
      platform: 'android',
      uidFingerprint: 'a' * 64,
      technologies: const <String>[],
      details: const <String, String>{},
      ndefRecords: const [],
      warnings: const <String>[],
    );

    expect(HistoryPrivacy.eventIdNeedsScrub(scan.id), isTrue);
    final String eventId = HistoryPrivacy.safeEventId(scan, ordinal: 4);

    expect(eventId, 'scan-1780000000000000-migrated-5');
    expect(eventId, isNot(contains('abcdef123456')));
    expect(
      HistoryPrivacy.sessionFingerprint(scan, eventId: eventId),
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );
  });
}
