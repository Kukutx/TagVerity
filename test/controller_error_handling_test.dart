import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/data/nfc/nfc_reader_service.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/nfc_support_status.dart';
import 'package:tagverity/domain/models/scan_settings.dart';
import 'package:tagverity/domain/models/tag_identity_stability.dart';
import 'package:tagverity/domain/repositories/scan_history_repository.dart';
import 'package:tagverity/domain/services/export_service.dart';
import 'package:tagverity/presentation/controllers/nfc_scan_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('disabled NFC blocks scan with actionable error', () async {
    final _Reader reader = _Reader(availability: NfcSupportStatus.disabled);
    final NfcScanController controller = _controller(reader: reader);
    await controller.initialize();

    await controller.startScan();

    expect(reader.startCalls, 0);
    expect(controller.isScanning, isFalse);
    expect(controller.errorMessage, contains('Turn on NFC'));
    controller.dispose();
  });

  test('reader terminal errors return controller to usable state', () async {
    final _Reader reader = _Reader(scanError: 'Scan timed out');
    final NfcScanController controller = _controller(reader: reader);
    await controller.initialize();

    await controller.startScan();

    expect(controller.isScanning, isFalse);
    expect(controller.errorMessage, 'Scan timed out');
    expect(
      controller.diagnosticEvents.any((event) => event.code == 'nfc.scan.failed'),
      isTrue,
    );
    controller.dispose();
  });

  test('share failures surface as UI error and diagnostics', () async {
    final _Reader reader = _Reader(scan: _scan());
    final NfcScanController controller = NfcScanController(
      readerService: reader,
      repository: _MemoryRepository(),
      exportService: _ThrowingExportService(),
    );
    await controller.initialize();
    await controller.startScan();

    await controller.shareCurrentScanJson();

    expect(controller.errorMessage, contains('Could not share report'));
    expect(
      controller.diagnosticEvents.any(
        (event) => event.code == 'export.share.failed',
      ),
      isTrue,
    );
    controller.dispose();
  });

  test('history persistence failure keeps scan visible and reports error', () async {
    final _Reader reader = _Reader(scan: _scan());
    final _MemoryRepository repository = _MemoryRepository(failSaveHistory: true);
    final NfcScanController controller = NfcScanController(
      readerService: reader,
      repository: repository,
      exportService: _NoopExportService(),
    );
    await controller.initialize();

    await controller.startScan();

    expect(controller.currentScan, isNotNull);
    expect(controller.history, hasLength(1));
    expect(controller.errorMessage, contains('Could not save scan history'));
    expect(
      controller.diagnosticEvents.any(
        (event) => event.code == 'storage.history.save.failed',
      ),
      isTrue,
    );
    controller.dispose();
  });
}

NfcScanController _controller({required _Reader reader}) {
  return NfcScanController(
    readerService: reader,
    repository: _MemoryRepository(),
    exportService: _NoopExportService(),
  );
}

NfcScan _scan() {
  return NfcScan(
    id: 'scan-1',
    scannedAt: DateTime.utc(2026, 9, 5),
    platform: 'android',
    uidHex: '04:AA:BB:CC',
    uidFingerprint: 'a' * 64,
    identityStability: TagIdentityStability.stable,
    technologies: const <String>['NfcA'],
    details: const <String, String>{
      'ndef.supported': 'yes',
      'ndef.readStatus': 'ok',
      'ndef.recordCount': '0',
    },
    ndefRecords: const [],
    warnings: const <String>[],
  );
}

final class _Reader implements NfcReaderService {
  _Reader({
    this.availability = NfcSupportStatus.enabled,
    this.scan,
    this.scanError,
  });

  final NfcSupportStatus availability;
  final NfcScan? scan;
  final String? scanError;
  int startCalls = 0;

  @override
  Future<NfcSupportStatus> checkAvailability() async => availability;

  @override
  Future<void> startScan({
    required ScanSettings settings,
    required ScanResultCallback onScan,
    required ScanErrorCallback onError,
  }) async {
    startCalls++;
    if (scanError case final String message) {
      onError(message);
      return;
    }
    if (scan case final NfcScan value) {
      await onScan(value);
      return;
    }
    onError('No test scan configured');
  }

  @override
  Future<void> stopScan() async {}
}

final class _MemoryRepository implements ScanHistoryRepository {
  _MemoryRepository({this.failSaveHistory = false});

  final bool failSaveHistory;
  List<NfcScan> history = <NfcScan>[];

  @override
  Future<void> clearHistory() async => history = <NfcScan>[];

  @override
  Future<List<NfcScan>> loadHistory() async => history;

  @override
  Future<ScanSettings> loadSettings() async => const ScanSettings();

  @override
  Future<void> saveHistory(List<NfcScan> scans) async {
    if (failSaveHistory) {
      throw StateError('disk unavailable');
    }
    history = List<NfcScan>.of(scans);
  }

  @override
  Future<void> saveSettings(ScanSettings settings) async {}
}

final class _NoopExportService implements ExportService {
  @override
  Future<void> shareTextFile({
    required String filename,
    required String content,
    required String mimeType,
    required String subject,
  }) async {}
}

final class _ThrowingExportService implements ExportService {
  @override
  Future<void> shareTextFile({
    required String filename,
    required String content,
    required String mimeType,
    required String subject,
  }) async {
    throw StateError('share unavailable');
  }
}
