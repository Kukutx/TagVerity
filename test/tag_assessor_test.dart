import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/tag_assessment.dart';
import 'package:tagverity/domain/models/tag_identity_stability.dart';
import 'package:tagverity/domain/services/tag_assessor.dart';

void main() {
  test('assessor marks a clean readable NDEF tag as healthy', () {
    final NfcScan scan = _scan(
      details: const <String, String>{
        'ndef.supported': 'yes',
        'ndef.recordCount': '1',
      },
    );

    expect(TagAssessor.assess(scan).status, TagAssessmentStatus.healthy);
  });

  test('assessor keeps privacy-scrubbed history assessment healthy', () {
    final NfcScan scan = _scan(
      uidHex: null,
      details: const <String, String>{
        'ndef.supported': 'yes',
        'ndef.recordCount': '1',
      },
    );

    expect(TagAssessor.assess(scan).status, TagAssessmentStatus.healthy);
  });

  test('assessor marks read warnings for review', () {
    final NfcScan scan = _scan(warnings: const <String>['Read warning']);

    expect(TagAssessor.assess(scan).status, TagAssessmentStatus.review);
  });

  test('assessor marks non-NDEF tags as limited', () {
    final NfcScan scan = _scan(
      details: const <String, String>{'ndef.supported': 'no'},
    );

    expect(TagAssessor.assess(scan).status, TagAssessmentStatus.limited);
  });
}

NfcScan _scan({
  String? uidHex = '04:AA:BB:CC',
  TagIdentityStability identityStability = TagIdentityStability.stable,
  Map<String, String> details = const <String, String>{'ndef.supported': 'yes'},
  List<String> warnings = const <String>[],
}) {
  return NfcScan(
    id: 'scan',
    scannedAt: DateTime.utc(2026, 9, 3),
    platform: 'android',
    uidHex: uidHex,
    uidFingerprint: '0123456789abcdef',
    identityStability: identityStability,
    technologies: const <String>['NfcA'],
    details: details,
    ndefRecords: const [],
    warnings: warnings,
  );
}
