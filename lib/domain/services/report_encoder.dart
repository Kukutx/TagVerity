import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/utils/byte_utils.dart';
import '../models/nfc_scan.dart';
import '../models/nfc_support_status.dart';
import '../models/scan_settings.dart';
import 'diagnostics_buffer.dart';
import 'scan_contract.dart';
import 'tag_assessor.dart';

abstract final class ReportEncoder {
  static Map<String, Object?> exportEnvelope(List<NfcScan> scans) {
    ScanContract.validateAll(scans);
    return <String, Object?>{
      'schemaVersion': AppConstants.exportSchemaVersion,
      'app': AppConstants.appName,
      'appVersion': AppConstants.appVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'readOnlyScope': true,
      'scans': scans
          .map((NfcScan scan) => scan.toJson())
          .toList(growable: false),
    };
  }

  static String prettyJson(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  static Map<String, Object?> diagnosticsEnvelope({
    required NfcSupportStatus supportStatus,
    required bool isScanning,
    required int historyCount,
    required int batchCount,
    required ScanSettings settings,
    required bool privacySettingsRecoveryRequired,
    required DiagnosticsBuffer diagnostics,
  }) {
    if (historyCount < 0 || batchCount < 0) {
      throw const FormatException('Diagnostics counts cannot be negative.');
    }
    return <String, Object?>{
      'schemaVersion': AppConstants.diagnosticsSchemaVersion,
      'app': AppConstants.appName,
      'appVersion': AppConstants.appVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'supportStatus': supportStatus.name,
      'isScanning': isScanning,
      'historyCount': historyCount,
      'batchCount': batchCount,
      'privacySettingsRecoveryRequired': privacySettingsRecoveryRequired,
      'settings': settings.toJson(),
      'events': diagnostics.events
          .map((event) => event.toJson())
          .toList(growable: false),
    };
  }

  static String batchCsv(List<NfcScan> scans) {
    ScanContract.validateAll(scans);
    final Map<String, int> comparableIdentityCounts = <String, int>{};
    for (final NfcScan scan in scans) {
      if (!scan.hasComparableIdentity) {
        continue;
      }
      comparableIdentityCounts.update(
        scan.uidFingerprint,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
    }
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
              ? comparableIdentityCounts[scan.uidFingerprint]! > 1
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
