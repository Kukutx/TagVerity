import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/tag_identity_stability.dart';

void main() {
  test('identity stability survives JSON round-trip', () {
    final NfcScan scan = NfcScan(
      id: 'scan-1',
      scannedAt: DateTime.utc(2026, 9, 5),
      platform: 'android',
      uidHex: '04:AA:BB:CC',
      uidFingerprint: 'a' * 64,
      identityStability: TagIdentityStability.stable,
      technologies: const <String>['NfcA'],
      details: const <String, String>{},
      ndefRecords: const [],
      warnings: const <String>[],
    );

    final NfcScan restored = NfcScan.fromJson(
      Map<String, dynamic>.from(scan.toJson()),
    );

    expect(restored.identityStability, TagIdentityStability.stable);
    expect(restored.hasComparableIdentity, isTrue);
  });

  test('legacy JSON defaults identity stability to unknown', () {
    final NfcScan restored = NfcScan.fromJson(<String, dynamic>{
      'id': 'legacy',
      'scannedAt': '2026-09-05T00:00:00Z',
      'platform': 'ios',
      'uidFingerprint': 'legacy-fingerprint',
      'technologies': <String>['MiFareIos'],
      'details': <String, String>{},
      'ndefRecords': <Object>[],
      'warnings': <String>[],
    });

    expect(restored.identityStability, TagIdentityStability.unknown);
    expect(restored.hasComparableIdentity, isFalse);
  });
}
