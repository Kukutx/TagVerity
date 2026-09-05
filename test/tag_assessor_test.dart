import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/tag_assessment.dart';
import 'package:tagverity/domain/models/tag_identity_stability.dart';
import 'package:tagverity/domain/services/tag_assessor.dart';

void main() {
  test('clean readable NDEF tag is healthy', () {
    expect(
      TagAssessor.assess(
        _scan(
          details: const <String, String>{
            'ndef.supported': 'yes',
            'ndef.readStatus': 'ok',
            'ndef.recordCount': '1',
          },
        ),
      ).status,
      TagAssessmentStatus.healthy,
    );
  });
  test('non-NDEF smart card can still pass basic checks', () {
    final TagAssessment assessment = TagAssessor.assess(
      _scan(details: const <String, String>{'ndef.supported': 'no'}),
    );
    expect(assessment.status, TagAssessmentStatus.healthy);
    expect(
      assessment.items.singleWhere((item) => item.title == 'NDEF').state,
      TagCheckState.info,
    );
  });
  test('disabled NDEF reading is limited without claiming no NDEF support', () {
    final TagAssessment assessment = TagAssessor.assess(
      _scan(
        details: const <String, String>{
          'ndef.supported': 'yes',
          'ndef.readStatus': 'disabled',
        },
      ),
    );
    expect(assessment.status, TagAssessmentStatus.limited);
    expect(assessment.summary, contains('reading is disabled'));
  });
  test('NDEF read failure needs review', () {
    expect(
      TagAssessor.assess(
        _scan(
          details: const <String, String>{
            'ndef.supported': 'yes',
            'ndef.readStatus': 'error',
          },
          warnings: const <String>['Could not read standard NDEF'],
        ),
      ).status,
      TagAssessmentStatus.review,
    );
  });
  test('session-only identity is informational rather than review', () {
    final TagAssessment assessment = TagAssessor.assess(
      _scan(uidHex: null, identityStability: TagIdentityStability.sessionOnly),
    );
    expect(assessment.status, TagAssessmentStatus.healthy);
    expect(
      assessment.items
          .singleWhere((item) => item.title == 'Tag identity')
          .state,
      TagCheckState.info,
    );
  });
}

NfcScan _scan({
  String? uidHex = '04:AA:BB:CC',
  TagIdentityStability identityStability = TagIdentityStability.stable,
  Map<String, String> details = const <String, String>{
    'ndef.supported': 'yes',
    'ndef.readStatus': 'ok',
    'ndef.recordCount': '0',
  },
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
