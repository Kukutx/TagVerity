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

  test('failed history write does not poison later queued mutations', () async {
    final repository = _FailFirstSaveRepository();
    final controller = NfcScanController(
      readerService: _Reader(),
      repository: repository,
      exportService: _NoopExportService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    final Future<void> scanFuture = controller.startScan();
    await repository.firstSaveStarted.future;
    final Future<bool> clearFuture = controller.clearHistory();

    expect(controller.historyBusy, isTrue);
    repository.releaseFirstSave.complete();

    await scanFuture;
    expect(await clearFuture, isTrue);
    expect(repository.clearCalls, 1);
    expect(repository.history, isEmpty);
    expect(controller.history, isEmpty);
    expect(controller.historyBusy, isFalse);
  });
}

NfcScan _scan() => NfcScan(
  id: 'queue-scan',
  scannedAt: DateTime.utc(2026, 9, 5),
  platform: 'android',
  uidHex: '04:AA:BB:CC',
  uidFingerprint: '0123456789abcdef0123456789abcdef',
  identityStability: TagIdentityStability.stable,
  technologies: const <String>['NfcA'],
  details: const <String, String>{
    'ndef.supported': 'no',
    'ndef.readStatus': 'not-supported',
  },
  ndefRecords: const [],
  warnings: const [],
);

final class _Reader implements NfcReaderService {
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

final class _FailFirstSaveRepository implements ScanHistoryRepository {
  final Completer<void> firstSaveStarted = Completer<void>();
  final Completer<void> releaseFirstSave = Completer<void>();
  List<NfcScan> history = <NfcScan>[];
  ScanSettings settings = const ScanSettings();
  int saveCalls = 0;
  int clearCalls = 0;

  @override
  Future<List<NfcScan>> loadHistory() async => List<NfcScan>.of(history);

  @override
  Future<ScanSettings> loadSettings() async => settings;

  @override
  Future<void> saveHistory(List<NfcScan> scans) async {
    saveCalls += 1;
    if (saveCalls == 1) {
      firstSaveStarted.complete();
      await releaseFirstSave.future;
      throw StateError('simulated first history write failure');
    }
    history = List<NfcScan>.of(scans);
  }

  @override
  Future<void> saveSettings(ScanSettings value) async {
    settings = value;
  }

  @override
  Future<void> clearHistory() async {
    clearCalls += 1;
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
