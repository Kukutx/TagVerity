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
  test('NfcScan snapshots collection inputs and exposes immutable fields', () {
    final List<String> technologies = <String>['NfcA'];
    final Map<String, String> details = <String, String>{'protocol': 'NFC-A'};
    const NdefRecordInfo record = NdefRecordInfo(
      index: 0,
      typeNameFormat: 'wellKnown',
      type: 'T',
      identifierHex: '',
      payloadLength: 0,
      byteLength: 0,
      summary: 'Empty text record',
      payloadPreviewHex: '',
    );
    final List<NdefRecordInfo> records = <NdefRecordInfo>[record];
    final List<String> warnings = <String>['First warning'];

    final NfcScan scan = NfcScan(
      id: 'snapshot',
      scannedAt: DateTime.utc(2026, 9, 6),
      platform: 'android',
      uidFingerprint: 'a' * 64,
      technologies: technologies,
      details: details,
      ndefRecords: records,
      warnings: warnings,
    );

    technologies.add('NfcB');
    details['protocol'] = 'mutated';
    records.clear();
    warnings.add('Second warning');

    expect(scan.technologies, <String>['NfcA']);
    expect(scan.details, <String, String>{'protocol': 'NFC-A'});
    expect(scan.ndefRecords, <NdefRecordInfo>[record]);
    expect(scan.warnings, <String>['First warning']);

    expect(
      () => scan.technologies.add('IsoDep'),
      throwsA(isA<UnsupportedError>()),
    );
    expect(
      () => scan.details['protocol'] = 'changed',
      throwsA(isA<UnsupportedError>()),
    );
    expect(() => scan.ndefRecords.clear(), throwsA(isA<UnsupportedError>()));
    expect(() => scan.warnings.clear(), throwsA(isA<UnsupportedError>()));

    final Map<String, Object?> json = scan.toJson();
    (json['technologies']! as List<String>).add('IsoDep');
    (json['details']! as Map<String, String>)['protocol'] = 'json-mutated';
    (json['warnings']! as List<String>).clear();

    expect(scan.technologies, <String>['NfcA']);
    expect(scan.details['protocol'], 'NFC-A');
    expect(scan.warnings, <String>['First warning']);

    final List<String> replacementTechnologies = <String>['IsoDep'];
    final NfcScan copied = scan.copyWith(technologies: replacementTechnologies);
    replacementTechnologies.clear();
    expect(copied.technologies, <String>['IsoDep']);
  });

  test('NfcScan fromJson snapshots nested collection inputs', () {
    final Map<String, dynamic> json = <String, dynamic>{
      'id': 'json-snapshot',
      'scannedAt': '2026-09-06T00:00:00.000Z',
      'platform': 'android',
      'uidHex': null,
      'uidFingerprint': 'b' * 64,
      'identityStability': 'sessionOnly',
      'technologies': <String>['NfcA'],
      'details': <String, dynamic>{'protocol': 'NFC-A'},
      'ndefRecords': <Map<String, dynamic>>[],
      'warnings': <String>['warning'],
    };

    final NfcScan restored = NfcScan.fromJson(json);

    (json['technologies']! as List<String>).add('NfcB');
    (json['details']! as Map<String, dynamic>)['protocol'] = 'mutated';
    (json['warnings']! as List<String>).clear();

    expect(restored.technologies, <String>['NfcA']);
    expect(restored.details, <String, String>{'protocol': 'NFC-A'});
    expect(restored.warnings, <String>['warning']);
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
