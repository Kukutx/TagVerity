import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/utils/byte_utils.dart';
import '../models/batch_summary.dart';
import '../models/nfc_scan.dart';
import 'tag_assessor.dart';

abstract final class ReportEncoder {
  static Map<String, Object?> exportEnvelope(
    List<NfcScan> scans,
  ) => <String, Object?>{
    'schemaVersion': AppConstants.exportSchemaVersion,
    'app': AppConstants.appName,
    'appVersion': AppConstants.appVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'readOnlyScope': true,
    'scans': scans.map((NfcScan scan) => scan.toJson()).toList(growable: false),
  };
  static String prettyJson(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);
  static String batchCsv(List<NfcScan> scans, {BatchSummary? summary}) {
    final BatchSummary resolvedSummary =
        summary ?? BatchSummary.fromScans(scans);
    final Set<String> repeated = resolvedSummary.repeatedFingerprints;
    final StringBuffer buffer = StringBuffer()
      ..writeln(
        'scanned_at,short_fingerprint,identity_stability,technologies,'
        'ndef_records,status,warnings,repeated_id',
      );
    for (final NfcScan scan in scans) {
      buffer.writeln(
        <String>[
          scan.scannedAt.toUtc().toIso8601String(),
          ByteUtils.shortFingerprint(scan.uidFingerprint),
          scan.identityStability.name,
          scan.technologies.join(' | '),
          scan.ndefRecords.length.toString(),
          TagAssessor.assess(scan).status.name,
          scan.warnings.length.toString(),
          scan.hasComparableIdentity
              ? repeated.contains(scan.uidFingerprint)
                    ? 'yes'
                    : 'no'
              : 'unknown',
        ].map(_csv).join(','),
      );
    }
    return buffer.toString();
  }

  static String timestampForFilename() =>
      DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  static String _csv(String value) => '"${value.replaceAll('"', '""')}"';
}
