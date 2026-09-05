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
    expect(settings.readNdef, isTrue);
    expect(settings.saveRawUidInHistory, isFalse);
    expect(settings.saveNdefInHistory, isFalse);
    expect(settings.saveTechnicalIdentifiersInHistory, isFalse);
    final ScanSettings restored = ScanSettings.fromJson(
      Map<String, dynamic>.from(settings.toJson()),
    );
    expect(restored.toJson(), settings.toJson());
  });
  test('ScanSettings copyWith changes only requested behavior', () {
    const ScanSettings settings = ScanSettings();
    final ScanSettings updated = settings.copyWith(
      readNdef: false,
      saveRawUidInHistory: true,
    );
    expect(updated.readNdef, isFalse);
    expect(updated.saveRawUidInHistory, isTrue);
    expect(updated.saveNdefInHistory, isFalse);
    expect(updated.saveTechnicalIdentifiersInHistory, isFalse);
  });
}
