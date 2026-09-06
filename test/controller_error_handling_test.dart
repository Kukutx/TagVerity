import 'dart:async';

import 'package:flutter/services.dart';
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
  test(
    'reader start exceptions reset scanning state and surface globally',
    () async {
      final _Reader reader = _Reader(
        startException: StateError('native NFC session start timed out'),
      );
      final NfcScanController controller = _controller(reader: reader);
      await controller.initialize();

      await controller.startScan();

      expect(controller.isScanning, isFalse);
      expect(
        controller.errorMessage,
        contains('native NFC session start timed out'),
      );
      expect(
        controller.diagnosticEvents.any(
          (event) => event.code == 'nfc.scan.start.failed',
        ),
        isTrue,
      );
      controller.dispose();
    },
  );

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
  test('reader errors are bounded before reaching the global banner', () async {
    final _Reader reader = _Reader(
      scanError: 'native\nerror\t${'x' * 700}\u0000tail',
    );
    final NfcScanController controller = _controller(reader: reader);
    await controller.initialize();
    await controller.startScan();

    final String message = controller.errorMessage!;
    expect(message.runes.length, 500);
    expect(message, startsWith('native error '));
    expect(message, isNot(contains('\n')));
    expect(message, isNot(contains('\t')));
    expect(message, endsWith('…'));
    expect(controller.diagnosticEvents.last.message, message);
    controller.dispose();
  });

  test(
    'invalid scan models fail export preparation without false success',
    () async {
      final NfcScan invalid = _scan().copyWith(uidFingerprint: 'f' * 64);
      final NfcScanController controller = NfcScanController(
        readerService: _Reader(scan: invalid),
        repository: _MemoryRepository(),
        exportService: _NoopExportService(),
      );
      await controller.initialize();
      await controller.startScan();

      final bool copied = await controller.copyCurrentScanJson();

      expect(copied, isFalse);
      expect(controller.errorMessage, contains('Could not prepare scan JSON'));
      expect(
        controller.diagnosticEvents.any(
          (event) => event.code == 'export.encode.failed',
        ),
        isTrue,
      );
      controller.dispose();
    },
  );

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
      initialSettings: const ScanSettings(
        saveRawUidInHistory: true,
        saveNdefInHistory: true,
        saveTechnicalIdentifiersInHistory: true,
      ),
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
      expect(repository.history.single.id, 'scan-1');
      expect(repository.history.single.uidHex, isNull);
      expect(
        repository.history.single.identityStability,
        TagIdentityStability.sessionOnly,
      );
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
      (ScanSettings current) => current.copyWith(readNdef: false),
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
    final String comparableFingerprint =
        controller.history.single.uidFingerprint;
    expect(
      controller.history.single.identityStability,
      TagIdentityStability.stable,
    );
    final bool saved = await controller.updateSettings(
      (ScanSettings current) => current.copyWith(saveRawUidInHistory: false),
    );
    expect(saved, isTrue);
    expect(controller.settings.saveRawUidInHistory, isFalse);
    expect(controller.history.single.uidHex, isNull);
    expect(repository.history.single.uidHex, isNull);
    expect(
      controller.history.single.identityStability,
      TagIdentityStability.sessionOnly,
    );
    expect(
      controller.history.single.uidFingerprint,
      isNot(comparableFingerprint),
    );
    expect(
      repository.history.single.uidFingerprint,
      controller.history.single.uidFingerprint,
    );
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
      (ScanSettings current) => current.copyWith(saveRawUidInHistory: false),
    );
    expect(saved, isFalse);
    expect(controller.settings.saveRawUidInHistory, isFalse);
    expect(repository.settings.saveRawUidInHistory, isFalse);
    expect(
      controller.history.single.uidHex,
      isNull,
      reason:
          'the running app must never re-expose data after privacy is disabled',
    );
    expect(
      repository.history.single.uidHex,
      original.uidHex,
      reason: 'the simulated disk rewrite failed and remains for retry',
    );
    expect(
      controller.errorMessage,
      contains('saved history could not be scrubbed on disk'),
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
    'rapid settings updates merge against the latest committed state',
    () async {
      final _MemoryRepository repository = _MemoryRepository(
        initialSettings: const ScanSettings(
          saveRawUidInHistory: true,
          saveNdefInHistory: true,
        ),
      );
      final NfcScanController controller = NfcScanController(
        readerService: _Reader(),
        repository: repository,
        exportService: _NoopExportService(),
      );
      await controller.initialize();
      final Future<bool> rawUpdate = controller.updateSettings(
        (ScanSettings current) => current.copyWith(saveRawUidInHistory: false),
      );
      final Future<bool> ndefUpdate = controller.updateSettings(
        (ScanSettings current) => current.copyWith(saveNdefInHistory: false),
      );
      expect(controller.settingsBusy, isTrue);
      expect(await rawUpdate, isTrue);
      expect(await ndefUpdate, isTrue);
      expect(controller.settings.saveRawUidInHistory, isFalse);
      expect(controller.settings.saveNdefInHistory, isFalse);
      expect(repository.settings.saveRawUidInHistory, isFalse);
      expect(repository.settings.saveNdefInHistory, isFalse);
      expect(controller.settingsBusy, isFalse);
      controller.dispose();
    },
  );
  test('initialization enforces current history privacy settings', () async {
    final _MemoryRepository repository = _MemoryRepository(
      initialHistory: <NfcScan>[_scan()],
    );
    final NfcScanController controller = NfcScanController(
      readerService: _Reader(),
      repository: repository,
      exportService: _NoopExportService(),
    );

    await controller.initialize();

    expect(controller.history, hasLength(1));
    expect(controller.history.single.id, 'scan-1');
    expect(controller.history.single.uidHex, isNull);
    expect(
      controller.history.single.identityStability,
      TagIdentityStability.sessionOnly,
    );
    expect(
      controller.history.single.uidFingerprint,
      isNot('732f6986a0dc9a440072e6868883900086befc53f156041f3778bb763a3dbd95'),
    );
    expect(controller.history.single.ndefRecords, isEmpty);
    expect(controller.history.single.details['barcode.value'], isNull);
    expect(repository.history.single.uidHex, isNull);
    expect(repository.history.single.ndefRecords, isEmpty);
    expect(repository.history.single.details['barcode.value'], isNull);
    expect(
      controller.diagnosticEvents.any(
        (event) => event.code == 'storage.history.privacy_rewrite',
      ),
      isTrue,
    );
    controller.dispose();
  });

  test(
    'privacy rewrite failure never re-exposes stored sensitive history',
    () async {
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

      expect(controller.history.single.uidHex, isNull);
      expect(controller.history.single.ndefRecords, isEmpty);
      expect(controller.history.single.details['barcode.value'], isNull);
      expect(repository.history.single.uidHex, original.uidHex);
      expect(
        controller.errorMessage,
        contains('hidden safely in this session'),
      );
      expect(
        controller.diagnosticEvents.any(
          (event) => event.code == 'storage.history.privacy_rewrite.failed',
        ),
        isTrue,
      );
      controller.dispose();
    },
  );

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
  test(
    'settings load failure hides history without rewriting or overwriting it',
    () async {
      final NfcScan original = _scan();
      final _MemoryRepository repository = _MemoryRepository(
        initialHistory: <NfcScan>[original],
        failLoadSettings: true,
      );
      final _Reader reader = _Reader(scan: _scan());
      final NfcScanController controller = NfcScanController(
        readerService: reader,
        repository: repository,
        exportService: _NoopExportService(),
      );

      await controller.initialize();

      expect(controller.initialized, isTrue);
      expect(controller.privacySettingsRecoveryRequired, isTrue);
      expect(controller.history, isEmpty);
      expect(repository.history.single.uidHex, original.uidHex);
      expect(repository.loadHistoryCalls, 0);
      expect(repository.saveHistoryCalls, 0);
      expect(
        controller.errorMessage,
        contains('Could not load saved settings'),
      );

      await controller.startScan();
      expect(reader.startCalls, 0);
      expect(repository.history.single.uidHex, original.uidHex);
      expect(repository.saveHistoryCalls, 0);
      expect(controller.errorMessage, contains('privacy settings'));
      controller.startBatchSession();
      expect(controller.batchSessionActive, isFalse);
      expect(await controller.clearHistory(), isFalse);
      expect(repository.history.single.uidHex, original.uidHex);
      expect(repository.saveHistoryCalls, 0);
      controller.dispose();
    },
  );

  test(
    'settings changes stay history-neutral until explicit recovery',
    () async {
      final NfcScan original = _scan();
      final _MemoryRepository repository = _MemoryRepository(
        initialHistory: <NfcScan>[original],
        failLoadSettings: true,
      );
      final NfcScanController controller = NfcScanController(
        readerService: _Reader(),
        repository: repository,
        exportService: _NoopExportService(),
      );

      await controller.initialize();
      expect(controller.privacySettingsRecoveryRequired, isTrue);
      expect(controller.history, isEmpty);
      expect(repository.loadHistoryCalls, 0);
      expect(repository.saveHistoryCalls, 0);

      expect(
        await controller.updateSettings(
          (ScanSettings current) => current.copyWith(saveRawUidInHistory: true),
        ),
        isTrue,
      );
      expect(
        await controller.updateSettings(
          (ScanSettings current) =>
              current.copyWith(saveRawUidInHistory: false),
        ),
        isTrue,
      );
      expect(
        await controller.updateSettings(
          (ScanSettings current) => current.copyWith(
            saveRawUidInHistory: true,
            saveTechnicalIdentifiersInHistory: true,
          ),
        ),
        isTrue,
      );

      expect(controller.privacySettingsRecoveryRequired, isTrue);
      expect(controller.errorMessage, contains('still hidden'));
      expect(controller.history, isEmpty);
      expect(repository.loadHistoryCalls, 0);
      expect(repository.saveHistoryCalls, 0);
      expect(repository.history.single.uidHex, original.uidHex);
      expect(
        repository.history.single.details['barcode.value'],
        original.details['barcode.value'],
      );

      final bool recovered = await controller
          .applyCurrentPrivacySettingsToSavedHistory();

      expect(recovered, isTrue);
      expect(controller.privacySettingsRecoveryRequired, isFalse);
      expect(controller.history, hasLength(1));
      expect(controller.history.single.uidHex, original.uidHex);
      expect(
        controller.history.single.details['barcode.value'],
        original.details['barcode.value'],
      );
      expect(repository.loadHistoryCalls, 1);
      expect(repository.saveHistoryCalls, 0);
      expect(controller.errorMessage, isNull);
      controller.dispose();
    },
  );

  test(
    'explicit recovery applies the complete current privacy policy once',
    () async {
      final NfcScan original = _scan();
      final _MemoryRepository repository = _MemoryRepository(
        initialHistory: <NfcScan>[original],
        failLoadSettings: true,
      );
      final NfcScanController controller = NfcScanController(
        readerService: _Reader(),
        repository: repository,
        exportService: _NoopExportService(),
      );

      await controller.initialize();
      expect(controller.history, isEmpty);
      expect(repository.loadHistoryCalls, 0);

      final bool recovered = await controller
          .applyCurrentPrivacySettingsToSavedHistory();

      expect(recovered, isTrue);
      expect(controller.privacySettingsRecoveryRequired, isFalse);
      expect(controller.history, hasLength(1));
      expect(controller.history.single.uidHex, isNull);
      expect(controller.history.single.ndefRecords, isEmpty);
      expect(controller.history.single.details['barcode.value'], isNull);
      expect(repository.history.single.uidHex, isNull);
      expect(repository.loadHistoryCalls, 1);
      expect(repository.saveHistoryCalls, 1);
      expect(controller.errorMessage, isNull);
      controller.dispose();
    },
  );

  test('history recovery serializes behind pending settings and uses latest policy', () async {
    final NfcScan original = _scan();
    final _MemoryRepository repository = _MemoryRepository(
      initialHistory: <NfcScan>[original],
      failLoadSettings: true,
      blockFirstSaveSettings: true,
    );
    final NfcScanController controller = NfcScanController(
      readerService: _Reader(),
      repository: repository,
      exportService: _NoopExportService(),
    );

    await controller.initialize();

    final Future<bool> settingsFuture = controller.updateSettings(
      (ScanSettings current) => current.copyWith(
        saveRawUidInHistory: true,
        saveTechnicalIdentifiersInHistory: true,
      ),
    );
    await repository.saveSettingsStarted.future;
    expect(controller.settingsBusy, isTrue);
    expect(repository.saveSettingsCalls, 1);

    final Future<bool> recoveryFuture = controller
        .applyCurrentPrivacySettingsToSavedHistory();
    await Future<void>.delayed(Duration.zero);
    expect(repository.loadHistoryCalls, 0);
    expect(repository.saveSettingsCalls, 1);

    repository.releaseFirstSaveSettings.complete();

    expect(await settingsFuture, isTrue);
    expect(await recoveryFuture, isTrue);
    expect(controller.settings.saveRawUidInHistory, isTrue);
    expect(controller.settings.saveTechnicalIdentifiersInHistory, isTrue);
    expect(controller.privacySettingsRecoveryRequired, isFalse);
    expect(controller.history, hasLength(1));
    expect(controller.history.single.uidHex, original.uidHex);
    expect(
      controller.history.single.details['barcode.value'],
      original.details['barcode.value'],
    );
    expect(repository.saveSettingsCalls, 2);
    expect(repository.loadHistoryCalls, 1);
    expect(repository.saveHistoryCalls, 0);
    controller.dispose();
  });

  test(
    'privacy recovery can delete saved history without loading it',
    () async {
      final NfcScan original = _scan();
      final _Reader reader = _Reader(scan: _scan());
      final _MemoryRepository repository = _MemoryRepository(
        initialHistory: <NfcScan>[original],
        failLoadSettings: true,
      );
      final NfcScanController controller = NfcScanController(
        readerService: reader,
        repository: repository,
        exportService: _NoopExportService(),
      );

      await controller.initialize();

      final bool deleted = await controller
          .deleteSavedHistoryDuringPrivacyRecovery();

      expect(deleted, isTrue);
      expect(repository.clearHistoryCalls, 1);
      expect(repository.loadHistoryCalls, 0);
      expect(repository.saveHistoryCalls, 0);
      expect(repository.history, isEmpty);
      expect(controller.history, isEmpty);
      expect(controller.privacySettingsRecoveryRequired, isTrue);
      expect(controller.errorMessage, contains('Saved history was deleted'));

      await controller.startScan();
      expect(reader.startCalls, 0);

      expect(
        await controller.applyCurrentPrivacySettingsToSavedHistory(),
        isTrue,
      );
      expect(controller.privacySettingsRecoveryRequired, isFalse);
      expect(repository.loadHistoryCalls, 1);
      expect(controller.history, isEmpty);
      controller.dispose();
    },
  );

  test('failed recovery deletion keeps hidden saved history intact', () async {
    final NfcScan original = _scan();
    final _MemoryRepository repository = _MemoryRepository(
      initialHistory: <NfcScan>[original],
      failLoadSettings: true,
      failClearHistory: true,
    );
    final NfcScanController controller = NfcScanController(
      readerService: _Reader(),
      repository: repository,
      exportService: _NoopExportService(),
    );

    await controller.initialize();

    final bool deleted = await controller
        .deleteSavedHistoryDuringPrivacyRecovery();

    expect(deleted, isFalse);
    expect(repository.clearHistoryCalls, 1);
    expect(repository.loadHistoryCalls, 0);
    expect(repository.history, hasLength(1));
    expect(repository.history.single.uidHex, original.uidHex);
    expect(controller.history, isEmpty);
    expect(controller.privacySettingsRecoveryRequired, isTrue);
    expect(controller.errorMessage, contains('Could not delete saved history'));
    controller.dispose();
  });

  test('clipboard failures do not report false success', () async {
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard', message: 'unavailable');
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final NfcScanController controller = NfcScanController(
      readerService: _Reader(scan: _scan()),
      repository: _MemoryRepository(),
      exportService: _NoopExportService(),
    );
    await controller.initialize();
    await controller.startScan();

    final bool copied = await controller.copyCurrentScanJson();

    expect(copied, isFalse);
    expect(controller.errorMessage, contains('Could not copy scan JSON'));
    expect(
      controller.diagnosticEvents.any(
        (event) => event.code == 'export.copy.failed',
      ),
      isTrue,
    );
    controller.dispose();
  });

  test('continuous batch stops when history persistence fails', () async {
    final _MemoryRepository repository = _MemoryRepository(
      failSaveHistory: true,
    );
    final NfcScanController controller = NfcScanController(
      readerService: _Reader(scan: _scan()),
      repository: repository,
      exportService: _NoopExportService(),
    );
    await controller.initialize();

    await controller.startContinuousBatchScan();

    expect(controller.batchScans, hasLength(1));
    expect(controller.batchAutoContinue, isFalse);
    expect(controller.history, isEmpty);
    expect(controller.errorMessage, contains('Could not save scan history'));
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
    uidFingerprint:
        '732f6986a0dc9a440072e6868883900086befc53f156041f3778bb763a3dbd95',
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
    this.startException,
  });
  final NfcSupportStatus availability;
  final NfcScan? scan;
  final String? scanError;
  final Object? startException;
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
    if (startException case final Object error) {
      throw error;
    }
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
    this.failLoadSettings = false,
    this.blockFirstSaveSettings = false,
    List<NfcScan> initialHistory = const <NfcScan>[],
    ScanSettings initialSettings = const ScanSettings(),
  }) : history = List<NfcScan>.of(initialHistory),
       settings = initialSettings;
  final bool failSaveHistory;
  final bool failClearHistory;
  final bool failSaveSettings;
  final bool failLoadHistory;
  final bool failLoadSettings;
  final bool blockFirstSaveSettings;
  final Completer<void> saveSettingsStarted = Completer<void>();
  final Completer<void> releaseFirstSaveSettings = Completer<void>();
  int saveSettingsCalls = 0;
  int clearHistoryCalls = 0;
  int loadHistoryCalls = 0;
  int saveHistoryCalls = 0;
  List<NfcScan> history;
  ScanSettings settings;
  @override
  Future<void> clearHistory() async {
    clearHistoryCalls++;
    if (failClearHistory) throw StateError('disk unavailable');
    history = <NfcScan>[];
  }

  @override
  Future<List<NfcScan>> loadHistory() async {
    loadHistoryCalls++;
    if (failLoadHistory) throw const FormatException('corrupt history');
    return List<NfcScan>.of(history);
  }

  @override
  Future<ScanSettings> loadSettings() async {
    if (failLoadSettings) {
      throw const FormatException('corrupt settings');
    }
    return settings;
  }

  @override
  Future<void> saveHistory(List<NfcScan> scans) async {
    if (failSaveHistory) throw StateError('disk unavailable');
    saveHistoryCalls++;
    history = List<NfcScan>.of(scans);
  }

  @override
  Future<void> saveSettings(ScanSettings value) async {
    saveSettingsCalls++;
    if (blockFirstSaveSettings && saveSettingsCalls == 1) {
      if (!saveSettingsStarted.isCompleted) {
        saveSettingsStarted.complete();
      }
      await releaseFirstSaveSettings.future;
    }
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
