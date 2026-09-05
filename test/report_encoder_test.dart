import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/core/constants/app_constants.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/tag_identity_stability.dart';
import 'package:tagverity/domain/services/report_encoder.dart';

void main() {
  test('export envelope carries versioned read-only metadata', () {
    final Map<String, Object?> envelope = ReportEncoder.exportEnvelope(
      <NfcScan>[_scan('stable-a', TagIdentityStability.stable)],
    );

    expect(envelope['schemaVersion'], AppConstants.exportSchemaVersion);
    expect(envelope['app'], AppConstants.appName);
    expect(envelope['appVersion'], AppConstants.appVersion);
    expect(envelope['readOnlyScope'], isTrue);
    expect(DateTime.tryParse(envelope['exportedAt']! as String), isNotNull);
    final List<dynamic> scans = envelope['scans']! as List<dynamic>;
    expect(scans, hasLength(1));
    expect(
      (scans.single as Map<String, dynamic>)['identityStability'],
      'stable',
    );

    final String pretty = ReportEncoder.prettyJson(envelope);
    expect(() => jsonDecode(pretty), returnsNormally);
  });

  test(
    'batch CSV reports repeated, unique and session-only identity semantics',
    () {
      final List<NfcScan> scans = <NfcScan>[
        _scan('same', TagIdentityStability.stable),
        _scan('same', TagIdentityStability.stable),
        _scan('unique', TagIdentityStability.stable),
        _scan('session', TagIdentityStability.sessionOnly),
      ];

      final List<String> lines = ReportEncoder.batchCsv(scans)
          .trimRight()
          .split('\n');

      expect(lines, hasLength(5));
      expect(lines.first, contains('repeated_id'));
      expect(lines[1], endsWith('"yes"'));
      expect(lines[2], endsWith('"yes"'));
      expect(lines[3], endsWith('"no"'));
      expect(lines[4], endsWith('"unknown"'));
      for (final String line in lines.skip(1)) {
        expect(line.startsWith('"'), isTrue);
      }
    },
  );

  test('CSV escapes embedded quotes and filename timestamps avoid colons', () {
    final NfcScan scan = _scan(
      'quoted',
      TagIdentityStability.stable,
      technologies: const <String>['Tech "quoted"'],
    );
    final String csv = ReportEncoder.batchCsv(<NfcScan>[scan]);

    expect(csv, contains('"Tech ""quoted"""'));
    final String timestamp = ReportEncoder.timestampForFilename();
    expect(timestamp, isNot(contains(':')));
    expect(timestamp, matches(RegExp(r'^\d{4}-\d{2}-\d{2}T')));
  });
}

NfcScan _scan(
  String fingerprint,
  TagIdentityStability stability, {
  List<String> technologies = const <String>['NfcA'],
}) {
  return NfcScan(
    id: 'scan-$fingerprint',
    scannedAt: DateTime.utc(2026, 9, 5, 12, 34, 56),
    platform: 'android',
    uidHex: '04:AA:BB:CC',
    uidFingerprint: fingerprint,
    identityStability: stability,
    technologies: technologies,
    details: const <String, String>{
      'ndef.supported': 'no',
      'ndef.readStatus': 'not-supported',
    },
    ndefRecords: const [],
    warnings: const [],
  );
}
