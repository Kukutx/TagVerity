import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/data/nfc/nfc_reader_service.dart';
import 'package:tagverity/domain/models/ndef_record_info.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/nfc_support_status.dart';
import 'package:tagverity/domain/models/scan_settings.dart';
import 'package:tagverity/domain/repositories/scan_history_repository.dart';
import 'package:tagverity/domain/services/export_service.dart';
import 'package:tagverity/presentation/controllers/nfc_scan_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('controller privacy-scrubs history by default', () async {
    final _MemoryRepository repository = _MemoryRepository();
    final NfcScanController controller = NfcScanController(
      readerService: _FakeReaderService(<NfcScan>[
        _scan('scan-1', '0123456789abcdef'),
      ]),
      repository: repository,
      exportService: _FakeExportService(),
    );
    await controller.initialize();

    await controller.startScan();

    expect(controller.currentScan?.uidHex, '04:AA:BB:CC');
    expect(controller.history, hasLength(1));
    expect(controller.history.single.uidHex, isNull);
    expect(controller.currentScan?.ndefRecords, hasLength(1));
    expect(controller.history.single.ndefRecords, isEmpty);
    expect(controller.history.single.details['barcode.value'], isNull);
    expect(controller.history.single.details['nfca.sak'], '0x00');
    expect(repository.history.single.uidHex, isNull);
    expect(repository.history.single.ndefRecords, isEmpty);
    final completion = controller.diagnosticEvents.singleWhere(
      (event) => event.code == 'nfc.scan.complete',
    );
    expect(completion.data.containsKey('uidHex'), isFalse);
    expect(completion.data.containsKey('uidFingerprint'), isFalse);
    controller.dispose();
  });

  test('batch mode detects duplicate tag fingerprints', () async {
    final _MemoryRepository repository = _MemoryRepository();
    final NfcScanController controller = NfcScanController(
      readerService: _FakeReaderService(<NfcScan>[
        _scan('scan-1', '0123456789abcdef'),
        _scan('scan-2', '0123456789abcdef'),
      ]),
      repository: repository,
      exportService: _FakeExportService(),
    );
    await controller.initialize();

    controller.startBatchSession();
    await controller.startBatchScan();
    await controller.startBatchScan();

    expect(controller.batchScans, hasLength(2));
    expect(controller.batchUniqueCount, 1);
    expect(controller.batchDuplicateFingerprints, <String>{'0123456789abcdef'});
    controller.finishBatchSession();
    expect(controller.batchSessionActive, isFalse);
    controller.dispose();
  });
}

NfcScan _scan(String id, String fingerprint) {
  return NfcScan(
    id: id,
    scannedAt: DateTime.utc(2026, 9, 3),
    platform: 'android',
    uidHex: '04:AA:BB:CC',
    uidFingerprint: fingerprint,
    technologies: const <String>['NfcA'],
    details: const <String, String>{
      'nfca.sak': '0x00',
      'barcode.value': 'AA:BB:CC:DD',
      'ndef.supported': 'yes',
      'ndef.recordCount': '1',
    },
    ndefRecords: const <NdefRecordInfo>[
      NdefRecordInfo(
        index: 0,
        typeNameFormat: 'wellKnown',
        type: 'T',
        identifierHex: '',
        payloadLength: 5,
        byteLength: 8,
        summary: 'Hello',
        payloadPreviewHex: '48:65:6C:6C:6F',
      ),
    ],
    warnings: const <String>[],
  );
}

final class _FakeReaderService implements NfcReaderService {
  _FakeReaderService(this.scans);

  final List<NfcScan> scans;
  int _index = 0;

  @override
  Future<NfcSupportStatus> checkAvailability() async =>
      NfcSupportStatus.enabled;

  @override
  Future<void> startScan({
    required ScanSettings settings,
    required ScanResultCallback onScan,
    required ScanErrorCallback onError,
  }) async {
    if (_index >= scans.length) {
      onError('No fake scan available');
      return;
    }
    await onScan(scans[_index++]);
  }

  @override
  Future<void> stopScan() async {}
}

final class _MemoryRepository implements ScanHistoryRepository {
  List<NfcScan> history = <NfcScan>[];
  ScanSettings settings = const ScanSettings();

  @override
  Future<void> clearHistory() async => history = <NfcScan>[];

  @override
  Future<List<NfcScan>> loadHistory() async => history;

  @override
  Future<ScanSettings> loadSettings() async => settings;

  @override
  Future<void> saveHistory(List<NfcScan> scans) async {
    history = List<NfcScan>.of(scans);
  }

  @override
  Future<void> saveSettings(ScanSettings value) async {
    settings = value;
  }
}

final class _FakeExportService implements ExportService {
  @override
  Future<void> shareTextFile({
    required String filename,
    required String content,
    required String mimeType,
    required String subject,
  }) async {}
}
