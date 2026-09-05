import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/domain/models/batch_summary.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/tag_identity_stability.dart';

void main() {
  test('BatchSummary computes quality and identity metrics in one pass', () {
    final List<NfcScan> scans = <NfcScan>[
      _scan('a', 'same'),
      _scan('b', 'same'),
      _scan('c', 'session-only', identity: TagIdentityStability.sessionOnly),
      _scan('d', 'review', warnings: const <String>['NDEF read failed']),
    ];
    final BatchSummary summary = BatchSummary.fromScans(scans);
    expect(summary.total, 4);
    expect(summary.healthy, 3);
    expect(summary.review, 1);
    expect(summary.comparable, 3);
    expect(summary.sessionOnly, 1);
    expect(summary.distinctComparableIds, 2);
    expect(summary.repeatedFingerprints, <String>{'same'});
  });
}

NfcScan _scan(
  String id,
  String fingerprint, {
  TagIdentityStability identity = TagIdentityStability.stable,
  List<String> warnings = const <String>[],
}) {
  return NfcScan(
    id: id,
    scannedAt: DateTime.utc(2026, 9, 5),
    platform: 'android',
    uidFingerprint: fingerprint,
    identityStability: identity,
    technologies: const <String>['NfcA'],
    details: const <String, String>{
      'ndef.supported': 'yes',
      'ndef.readStatus': 'ok',
      'ndef.recordCount': '0',
    },
    ndefRecords: const [],
    warnings: warnings,
  );
}
