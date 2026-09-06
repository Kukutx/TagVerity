import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/data/nfc/nfc_reader_service.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/nfc_support_status.dart';
import 'package:tagverity/domain/models/scan_settings.dart';
import 'package:tagverity/domain/repositories/scan_history_repository.dart';
import 'package:tagverity/domain/services/export_service.dart';
import 'package:tagverity/presentation/controllers/nfc_scan_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'availability failures degrade to unknown without breaking initialization',
    () async {
      final _Reader reader = _Reader(failAvailability: true);
      final NfcScanController controller = _controller(
        reader,
        _MemoryRepository(),
      );

      await controller.initialize();

      expect(controller.initialized, isTrue);
      expect(controller.supportStatus, NfcSupportStatus.unknown);
      expect(
        controller.diagnosticEvents.any(
          (event) => event.code == 'nfc.availability.check.failed',
        ),
        isTrue,
      );
      controller.dispose();
    },
  );

  test('older availability results cannot overwrite newer refreshes', () async {
    final _SequencedAvailabilityReader reader = _SequencedAvailabilityReader();
    final NfcScanController controller = _controller(
      reader,
      _MemoryRepository(),
    );
    await controller.initialize();

    final Completer<NfcSupportStatus> older = Completer<NfcSupportStatus>();
    final Completer<NfcSupportStatus> newer = Completer<NfcSupportStatus>();
    reader.responses
      ..add(older.future)
      ..add(newer.future);

    final Future<NfcSupportStatus> olderRefresh = controller
        .refreshAvailability();
    final Future<NfcSupportStatus> newerRefresh = controller
        .refreshAvailability();

    newer.complete(NfcSupportStatus.disabled);
    expect(await newerRefresh, NfcSupportStatus.disabled);
    expect(controller.supportStatus, NfcSupportStatus.disabled);

    older.complete(NfcSupportStatus.enabled);
    expect(await olderRefresh, NfcSupportStatus.disabled);
    expect(controller.supportStatus, NfcSupportStatus.disabled);

    controller.dispose();
  });

  test(
    'stale availability failures do not create misleading diagnostics',
    () async {
      final _SequencedAvailabilityReader reader =
          _SequencedAvailabilityReader();
      final NfcScanController controller = _controller(
        reader,
        _MemoryRepository(),
      );
      await controller.initialize();

      final Completer<NfcSupportStatus> older = Completer<NfcSupportStatus>();
      final Completer<NfcSupportStatus> newer = Completer<NfcSupportStatus>();
      reader.responses
        ..add(older.future)
        ..add(newer.future);
      final int failuresBefore = controller.diagnosticEvents
          .where((event) => event.code == 'nfc.availability.check.failed')
          .length;

      final Future<NfcSupportStatus> olderRefresh = controller
          .refreshAvailability();
      final Future<NfcSupportStatus> newerRefresh = controller
          .refreshAvailability();

      newer.complete(NfcSupportStatus.enabled);
      expect(await newerRefresh, NfcSupportStatus.enabled);
      older.completeError(StateError('stale availability failure'));
      expect(await olderRefresh, NfcSupportStatus.enabled);
      expect(
        controller.diagnosticEvents
            .where((event) => event.code == 'nfc.availability.check.failed')
            .length,
        failuresBefore,
      );

      controller.dispose();
    },
  );

  test('scanning is blocked while a settings write is pending', () async {
    final _BlockingSettingsRepository repository =
        _BlockingSettingsRepository();
    final _Reader reader = _Reader();
    final NfcScanController controller = _controller(reader, repository);
    await controller.initialize();

    final Future<bool> updateFuture = controller.updateSettings(
      (ScanSettings current) => current.copyWith(readNdef: false),
    );
    await repository.saveStarted.future;

    expect(controller.settingsBusy, isTrue);
    await controller.startScan();

    expect(reader.startCalls, 0);
    expect(controller.errorMessage, contains('pending settings update'));

    repository.releaseSave.complete();
    expect(await updateFuture, isTrue);
    controller.dispose();
  });

  test(
    'batch does not create a session while a settings write is pending',
    () async {
      final _BlockingSettingsRepository repository =
          _BlockingSettingsRepository();
      final _Reader reader = _Reader();
      final NfcScanController controller = _controller(reader, repository);
      await controller.initialize();

      final Future<bool> updateFuture = controller.updateSettings(
        (ScanSettings current) => current.copyWith(readNdef: false),
      );
      await repository.saveStarted.future;

      await controller.startContinuousBatchScan();

      expect(controller.batchSessionActive, isFalse);
      expect(controller.batchAutoContinue, isFalse);
      expect(reader.startCalls, 0);
      expect(controller.errorMessage, contains('pending settings update'));

      repository.releaseSave.complete();
      expect(await updateFuture, isTrue);
      controller.dispose();
    },
  );
}

NfcScanController _controller(
  NfcReaderService reader,
  ScanHistoryRepository repository,
) {
  return NfcScanController(
    readerService: reader,
    repository: repository,
    exportService: _NoopExportService(),
  );
}

final class _SequencedAvailabilityReader implements NfcReaderService {
  final List<Future<NfcSupportStatus>> responses = <Future<NfcSupportStatus>>[];
  int _availabilityCalls = 0;

  @override
  Future<NfcSupportStatus> checkAvailability() {
    if (_availabilityCalls++ == 0) {
      return Future<NfcSupportStatus>.value(NfcSupportStatus.enabled);
    }
    return responses.removeAt(0);
  }

  @override
  Future<void> startScan({
    required ScanSettings settings,
    required ScanResultCallback onScan,
    required ScanErrorCallback onError,
  }) async {}

  @override
  Future<void> stopScan() async {}
}

final class _Reader implements NfcReaderService {
  _Reader({this.failAvailability = false});

  final bool failAvailability;
  int startCalls = 0;

  @override
  Future<NfcSupportStatus> checkAvailability() async {
    if (failAvailability) {
      throw StateError('availability unavailable');
    }
    return NfcSupportStatus.enabled;
  }

  @override
  Future<void> startScan({
    required ScanSettings settings,
    required ScanResultCallback onScan,
    required ScanErrorCallback onError,
  }) async {
    startCalls += 1;
    onError('No scan expected in this test');
  }

  @override
  Future<void> stopScan() async {}
}

class _MemoryRepository implements ScanHistoryRepository {
  ScanSettings settings = const ScanSettings();
  List<NfcScan> history = <NfcScan>[];

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

  @override
  Future<void> clearHistory() async {
    history = <NfcScan>[];
  }
}

final class _BlockingSettingsRepository extends _MemoryRepository {
  final Completer<void> saveStarted = Completer<void>();
  final Completer<void> releaseSave = Completer<void>();

  @override
  Future<void> saveSettings(ScanSettings value) async {
    if (!saveStarted.isCompleted) {
      saveStarted.complete();
    }
    await releaseSave.future;
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
