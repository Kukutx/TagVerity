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
  test('rapid scan starts create only one reader session', () async {
    final _ControlledReader reader = _ControlledReader();
    final NfcScanController controller = _controller(reader);
    await controller.initialize();
    reader.availabilityCompleter = Completer<NfcSupportStatus>();
    final Future<void> first = controller.startScan();
    await Future<void>.delayed(Duration.zero);
    final Future<void> second = controller.startScan();
    expect(controller.isScanning, isTrue);
    reader.availabilityCompleter!.complete(NfcSupportStatus.enabled);
    await Future.wait(<Future<void>>[first, second]);
    expect(reader.startCalls, 1);
    controller.dispose();
  });
  test(
    'stop during availability check prevents native session start',
    () async {
      final _ControlledReader reader = _ControlledReader();
      final NfcScanController controller = _controller(reader);
      await controller.initialize();
      reader.availabilityCompleter = Completer<NfcSupportStatus>();
      final Future<void> starting = controller.startScan();
      await Future<void>.delayed(Duration.zero);
      await controller.stopScan();
      reader.availabilityCompleter!.complete(NfcSupportStatus.enabled);
      await starting;
      expect(reader.startCalls, 0);
      expect(controller.isScanning, isFalse);
      expect(controller.currentScan, isNull);
      controller.dispose();
    },
  );
  test('late scan callback after stop is ignored', () async {
    final _ControlledReader reader = _ControlledReader();
    final NfcScanController controller = _controller(reader);
    await controller.initialize();
    await controller.startScan();
    await controller.stopScan();
    await reader.emitScan(_scan());
    expect(controller.currentScan, isNull);
    expect(controller.history, isEmpty);
    controller.dispose();
  });
  test('late error callback after stop is ignored', () async {
    final _ControlledReader reader = _ControlledReader();
    final NfcScanController controller = _controller(reader);
    await controller.initialize();
    await controller.startScan();
    await controller.stopScan();
    reader.emitError('late reader error');
    expect(controller.errorMessage, isNull);
    controller.dispose();
  });
  test('finishing a batch ignores a late batch callback', () async {
    final _ControlledReader reader = _ControlledReader();
    final NfcScanController controller = _controller(reader);
    await controller.initialize();
    controller.startBatchSession();
    await controller.startBatchScan();
    controller.finishBatchSession();
    await Future<void>.delayed(Duration.zero);
    await reader.emitScan(_scan());
    expect(controller.batchScans, isEmpty);
    expect(controller.history, isEmpty);
    expect(controller.currentScan, isNull);
    controller.dispose();
  });
  test('finishing batch does not stop an unrelated single scan', () async {
    final _ControlledReader reader = _ControlledReader();
    final NfcScanController controller = _controller(reader);
    await controller.initialize();
    controller.startBatchSession();
    await controller.startScan();
    final int stopsBeforeFinish = reader.stopCalls;
    controller.finishBatchSession();
    await Future<void>.delayed(Duration.zero);
    expect(reader.stopCalls, stopsBeforeFinish);
    expect(controller.isScanning, isTrue);
    await controller.stopScan();
    controller.dispose();
  });
  test('batch cannot start while a single scan is active', () async {
    final _ControlledReader reader = _ControlledReader();
    final NfcScanController controller = _controller(reader);
    await controller.initialize();
    await controller.startScan();
    controller.startBatchSession();
    expect(controller.batchSessionActive, isFalse);
    expect(controller.errorMessage, contains('Stop the current scan'));
    await controller.stopScan();
    controller.dispose();
  });
}

NfcScanController _controller(_ControlledReader reader) {
  return NfcScanController(
    readerService: reader,
    repository: _MemoryRepository(),
    exportService: _NoopExportService(),
  );
}

NfcScan _scan() {
  return NfcScan(
    id: 'scan',
    scannedAt: DateTime.utc(2026, 9, 5),
    platform: 'android',
    uidHex: '04:AA:BB:CC',
    uidFingerprint: '0123456789abcdef',
    identityStability: TagIdentityStability.stable,
    technologies: const <String>['NfcA'],
    details: const <String, String>{
      'ndef.supported': 'yes',
      'ndef.readStatus': 'ok',
      'ndef.recordCount': '0',
    },
    ndefRecords: const [],
    warnings: const [],
  );
}

final class _ControlledReader implements NfcReaderService {
  Completer<NfcSupportStatus>? availabilityCompleter;
  int startCalls = 0;
  int stopCalls = 0;
  ScanResultCallback? _onScan;
  ScanErrorCallback? _onError;
  @override
  Future<NfcSupportStatus> checkAvailability() {
    return availabilityCompleter?.future ??
        Future<NfcSupportStatus>.value(NfcSupportStatus.enabled);
  }

  @override
  Future<void> startScan({
    required ScanSettings settings,
    required ScanResultCallback onScan,
    required ScanErrorCallback onError,
  }) async {
    startCalls += 1;
    _onScan = onScan;
    _onError = onError;
  }

  @override
  Future<void> stopScan() async {
    stopCalls += 1;
  }

  Future<void> emitScan(NfcScan scan) async {
    final ScanResultCallback? callback = _onScan;
    if (callback != null) {
      await callback(scan);
    }
  }

  void emitError(String message) {
    _onError?.call(message);
  }
}

final class _MemoryRepository implements ScanHistoryRepository {
  List<NfcScan> history = <NfcScan>[];
  ScanSettings settings = const ScanSettings();
  @override
  Future<void> clearHistory() async {
    history = <NfcScan>[];
  }

  @override
  Future<List<NfcScan>> loadHistory() async => List<NfcScan>.of(history);
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

final class _NoopExportService implements ExportService {
  @override
  Future<void> shareTextFile({
    required String filename,
    required String content,
    required String mimeType,
    required String subject,
  }) async {}
}
