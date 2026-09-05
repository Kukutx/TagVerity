import 'dart:async';

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

  test(
    'history clear waits for an in-flight scan save and wins deterministically',
    () async {
      final _BlockingRepository repository = _BlockingRepository();
      final NfcScanController controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.initialize();

      final Future<void> scanFuture = controller.startScan();
      await repository.firstSaveStarted.future;
      final Future<bool> clearFuture = controller.clearHistory();

      expect(controller.historyBusy, isTrue);
      repository.releaseFirstSave.complete();

      await scanFuture;
      expect(await clearFuture, isTrue);
      expect(controller.history, isEmpty);
      expect(repository.history, isEmpty);
      expect(controller.historyBusy, isFalse);
    },
  );

  test('privacy disable queues behind scan save and leaves disk and memory scrubbed', () async {
    final _BlockingRepository repository = _BlockingRepository(
      initialSettings: const ScanSettings(saveRawUidInHistory: true),
    );
    final NfcScanController controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    final Future<void> scanFuture = controller.startScan();
    await repository.firstSaveStarted.future;
    final Future<bool> privacyFuture = controller.updateSettings(
      (ScanSettings current) => current.copyWith(saveRawUidInHistory: false),
    );

    expect(controller.settingsBusy, isTrue);
    repository.releaseFirstSave.complete();

    await scanFuture;
    expect(await privacyFuture, isTrue);
    expect(controller.settings.saveRawUidInHistory, isFalse);
    expect(repository.settings.saveRawUidInHistory, isFalse);
    expect(controller.history, hasLength(1));
    expect(repository.history, hasLength(1));
    expect(controller.history.single.uidHex, isNull);
    expect(repository.history.single.uidHex, isNull);
    expect(controller.historyBusy, isFalse);
    expect(controller.settingsBusy, isFalse);
  });
}

NfcScanController _controller(_BlockingRepository repository) {
  return NfcScanController(
    readerService: _SingleScanReader(),
    repository: repository,
    exportService: _NoopExportService(),
  );
}

NfcScan _scan() {
  return NfcScan(
    id: 'race-scan',
    scannedAt: DateTime.utc(2026, 9, 5),
    platform: 'android',
    uidHex: '04:AA:BB:CC',
    uidFingerprint:
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    identityStability: TagIdentityStability.stable,
    technologies: const <String>['NfcA'],
    details: const <String, String>{
      'ndef.supported': 'no',
      'ndef.readStatus': 'not-supported',
    },
    ndefRecords: const [],
    warnings: const [],
  );
}

final class _SingleScanReader implements NfcReaderService {
  @override
  Future<NfcSupportStatus> checkAvailability() async =>
      NfcSupportStatus.enabled;

  @override
  Future<void> startScan({
    required ScanSettings settings,
    required ScanResultCallback onScan,
    required ScanErrorCallback onError,
  }) async {
    await onScan(_scan());
  }

  @override
  Future<void> stopScan() async {}
}

final class _BlockingRepository implements ScanHistoryRepository {
  _BlockingRepository({this.initialSettings = const ScanSettings()})
    : settings = initialSettings;

  final ScanSettings initialSettings;
  final Completer<void> firstSaveStarted = Completer<void>();
  final Completer<void> releaseFirstSave = Completer<void>();
  List<NfcScan> history = <NfcScan>[];
  ScanSettings settings;
  int saveHistoryCalls = 0;

  @override
  Future<List<NfcScan>> loadHistory() async => List<NfcScan>.of(history);

  @override
  Future<ScanSettings> loadSettings() async => settings;

  @override
  Future<void> saveHistory(List<NfcScan> scans) async {
    saveHistoryCalls++;
    if (saveHistoryCalls == 1) {
      firstSaveStarted.complete();
      await releaseFirstSave.future;
    }
    history = List<NfcScan>.of(scans);
  }

  @override
  Future<void> saveSettings(ScanSettings value) async {
    settings = value;
  }

  @override
  Future<void> clearHistory() async {
    history = <NfcScan>[];
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
