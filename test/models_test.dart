import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/domain/models/ndef_record_info.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/scan_settings.dart';

void main() {
  test('NfcScan JSON round-trip preserves public fields', () {
    final NfcScan scan = NfcScan(
      id: 'scan-1',
      scannedAt: DateTime.utc(2026, 7, 10, 12, 30),
      platform: 'android',
      uidHex: '04:AA:BB:CC',
      uidFingerprint: 'abc123',
      technologies: const <String>['NfcA', 'MifareUltralight'],
      details: const <String, String>{'nfca.sak': '0x00'},
      ndefRecords: const <NdefRecordInfo>[],
      warnings: const <String>[],
    );

    final NfcScan restored = NfcScan.fromJson(
      Map<String, dynamic>.from(scan.toJson()),
    );

    expect(restored.id, scan.id);
    expect(restored.uidHex, scan.uidHex);
    expect(restored.details, scan.details);
  });

  test('ScanSettings keeps sensitive history fields disabled by default', () {
    const ScanSettings settings = ScanSettings();

    expect(settings.saveRawUidInHistory, isFalse);
    expect(settings.saveNdefInHistory, isFalse);
    expect(settings.saveTechnicalIdentifiersInHistory, isFalse);

    final ScanSettings restored = ScanSettings.fromJson(
      Map<String, dynamic>.from(settings.toJson()),
    );
    expect(restored.saveRawUidInHistory, isFalse);
    expect(restored.saveNdefInHistory, isFalse);
    expect(restored.saveTechnicalIdentifiersInHistory, isFalse);
  });

  test('ScanSettings clamps limits', () {
    expect(const ScanSettings().copyWith(historyLimit: 1).historyLimit, 10);
    expect(const ScanSettings().copyWith(historyLimit: 999).historyLimit, 500);
    expect(
      const ScanSettings().copyWith(scanTimeoutSeconds: 1).scanTimeoutSeconds,
      5,
    );
    expect(
      const ScanSettings().copyWith(scanTimeoutSeconds: 999).scanTimeoutSeconds,
      120,
    );
  });
}
