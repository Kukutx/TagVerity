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
      controller.diagnosticEvents.any(
        (event) => event.code == 'nfc.scan.failed',
      ),
      isTrue,
    );
    controller.dispose();
  });
  test('share failures surface as global controller error', () async {
    final NfcScanController controller = NfcScanController(
      readerService: _Reader(scan: _scan()),
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
  test('failed sensitive scrub keeps original history visible', () async {
    final NfcScan original = _scan();
    final _MemoryRepository repository = _MemoryRepository(
      initialHistory: <NfcScan>[original],
      failSaveHistory: true,
    );
    final NfcScanController controller = NfcScanController(
      readerService: _Reader(),
      repository: repository,
      exportService: _NoopExportService(),
    );
    await controller.initialize();
    final bool removed = await controller.scrubSensitiveHistory();
    expect(removed, isFalse);
    expect(controller.history.single.uidHex, original.uidHex);
    expect(repository.history.single.uidHex, original.uidHex);
    expect(controller.errorMessage, contains('Remove sensitive data'));
    controller.dispose();
  });
  test(
    'successful sensitive scrub updates memory and persistence together',
    () async {
      final _MemoryRepository repository = _MemoryRepository(
        initialHistory: <NfcScan>[_scan()],
      );
      final NfcScanController controller = NfcScanController(
        readerService: _Reader(),
        repository: repository,
        exportService: _NoopExportService(),
      );
      await controller.initialize();
      final bool removed = await controller.scrubSensitiveHistory();
      expect(removed, isTrue);
      expect(controller.history.single.uidHex, isNull);
      expect(controller.history.single.details['barcode.value'], isNull);
      expect(repository.history.single.uidHex, isNull);
      controller.dispose();
    },
  );
  test('failed history clear keeps original history visible', () async {
    final _MemoryRepository repository = _MemoryRepository(
      initialHistory: <NfcScan>[_scan()],
      failClearHistory: true,
    );
    final NfcScanController controller = NfcScanController(
      readerService: _Reader(),
      repository: repository,
      exportService: _NoopExportService(),
    );
    await controller.initialize();
    final bool cleared = await controller.clearHistory();
    expect(cleared, isFalse);
    expect(controller.history, hasLength(1));
    expect(repository.history, hasLength(1));
    expect(controller.errorMessage, contains('Could not clear history'));
    controller.dispose();
  });
  test(
    'history persistence failure never creates fake saved history',
    () async {
      final _MemoryRepository repository = _MemoryRepository(
        failSaveHistory: true,
      );
      final NfcScanController controller = NfcScanController(
        readerService: _Reader(scan: _scan()),
        repository: repository,
        exportService: _NoopExportService(),
      );
      await controller.initialize();
      await controller.startScan();
      expect(controller.currentScan, isNotNull);
      expect(controller.history, isEmpty);
      expect(repository.history, isEmpty);
      expect(controller.errorMessage, contains('Could not save scan history'));
      controller.dispose();
    },
  );
  test('failed settings persistence keeps previous settings', () async {
    final _MemoryRepository repository = _MemoryRepository(
      failSaveSettings: true,
    );
    final NfcScanController controller = NfcScanController(
      readerService: _Reader(),
      repository: repository,
      exportService: _NoopExportService(),
    );
    await controller.initialize();
    final bool saved = await controller.updateSettings(
      controller.settings.copyWith(readNdef: false),
    );
    expect(saved, isFalse);
    expect(controller.settings.readNdef, isTrue);
    expect(repository.settings.readNdef, isTrue);
    expect(controller.errorMessage, contains('Could not save settings'));
    controller.dispose();
  });
  test('disabling sensitive retention scrubs matching saved history', () async {
    final _MemoryRepository repository = _MemoryRepository(
      initialHistory: <NfcScan>[_scan()],
      initialSettings: const ScanSettings(saveRawUidInHistory: true),
    );
    final NfcScanController controller = NfcScanController(
      readerService: _Reader(),
      repository: repository,
      exportService: _NoopExportService(),
    );
    await controller.initialize();
    final bool saved = await controller.updateSettings(
      controller.settings.copyWith(saveRawUidInHistory: false),
    );
    expect(saved, isTrue);
    expect(controller.settings.saveRawUidInHistory, isFalse);
    expect(controller.history.single.uidHex, isNull);
    expect(repository.history.single.uidHex, isNull);
    controller.dispose();
  });
  test('privacy setting stays disabled when historical scrub fails', () async {
    final NfcScan original = _scan();
    final _MemoryRepository repository = _MemoryRepository(
      initialHistory: <NfcScan>[original],
      initialSettings: const ScanSettings(saveRawUidInHistory: true),
      failSaveHistory: true,
    );
    final NfcScanController controller = NfcScanController(
      readerService: _Reader(),
      repository: repository,
      exportService: _NoopExportService(),
    );
    await controller.initialize();
    final bool saved = await controller.updateSettings(
      controller.settings.copyWith(saveRawUidInHistory: false),
    );
    expect(saved, isFalse);
    expect(controller.settings.saveRawUidInHistory, isFalse);
    expect(repository.settings.saveRawUidInHistory, isFalse);
    expect(controller.history.single.uidHex, original.uidHex);
    expect(repository.history.single.uidHex, original.uidHex);
    expect(
      controller.errorMessage,
      contains('saved history could not be scrubbed'),
    );
    expect(
      controller.diagnosticEvents.any(
        (event) => event.code == 'storage.history.scrub.after_setting.failed',
      ),
      isTrue,
    );
    controller.dispose();
  });
  test(
    'history load failure is visible without preventing initialization',
    () async {
      final _MemoryRepository repository = _MemoryRepository(
        failLoadHistory: true,
      );
      final NfcScanController controller = NfcScanController(
        readerService: _Reader(),
        repository: repository,
        exportService: _NoopExportService(),
      );
      await controller.initialize();
      expect(controller.initialized, isTrue);
      expect(controller.history, isEmpty);
      expect(controller.errorMessage, contains('Could not load saved history'));
      controller.dispose();
    },
  );
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
      'barcode.value': 'AA:BB:CC:DD',
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
  _MemoryRepository({
    this.failSaveHistory = false,
    this.failClearHistory = false,
    this.failSaveSettings = false,
    this.failLoadHistory = false,
    List<NfcScan> initialHistory = const <NfcScan>[],
    ScanSettings initialSettings = const ScanSettings(),
  }) : history = List<NfcScan>.of(initialHistory),
       settings = initialSettings;
  final bool failSaveHistory;
  final bool failClearHistory;
  final bool failSaveSettings;
  final bool failLoadHistory;
  List<NfcScan> history;
  ScanSettings settings;
  @override
  Future<void> clearHistory() async {
    if (failClearHistory) throw StateError('disk unavailable');
    history = <NfcScan>[];
  }

  @override
  Future<List<NfcScan>> loadHistory() async {
    if (failLoadHistory) throw const FormatException('corrupt history');
    return List<NfcScan>.of(history);
  }

  @override
  Future<ScanSettings> loadSettings() async => settings;
  @override
  Future<void> saveHistory(List<NfcScan> scans) async {
    if (failSaveHistory) throw StateError('disk unavailable');
    history = List<NfcScan>.of(scans);
  }

  @override
  Future<void> saveSettings(ScanSettings value) async {
    if (failSaveSettings) throw StateError('disk unavailable');
    settings = value;
  }
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
