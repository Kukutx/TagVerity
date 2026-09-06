import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:tagverity/data/nfc/nfc_manager_reader_service.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/scan_settings.dart';
import 'package:tagverity/domain/models/tag_identity_stability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'session timeout remains active while tag inspection is pending',
    () async {
      final _FakeNfcManager manager = _FakeNfcManager();
      final Completer<NfcScan> inspection = Completer<NfcScan>();
      final Completer<void> inspectionStarted = Completer<void>();
      int inspectionCalls = 0;
      final List<NfcScan> scans = <NfcScan>[];
      final List<String> errors = <String>[];
      final NfcManagerReaderService service = NfcManagerReaderService(
        manager: manager,
        scanTimeout: const Duration(milliseconds: 100),
        tagInspector: (NfcTag tag, ScanSettings settings) {
          inspectionCalls += 1;
          if (!inspectionStarted.isCompleted) {
            inspectionStarted.complete();
          }
          return inspection.future;
        },
      );

      await service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async => scans.add(scan),
        onError: errors.add,
      );
      manager.discover();
      manager.discover();
      await inspectionStarted.future;
      await Future<void>.delayed(const Duration(milliseconds: 180));

      expect(inspectionCalls, 1);
      expect(scans, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.single, contains('Scan timed out'));
      expect(manager.stopCalls, 1);

      inspection.complete(_scan());
      await Future<void>.delayed(Duration.zero);
      expect(scans, isEmpty);
      expect(errors, hasLength(1));
    },
  );

  test('successful tag inspection cancels the session timeout', () async {
    final _FakeNfcManager manager = _FakeNfcManager();
    final Completer<void> delivered = Completer<void>();
    final List<String> errors = <String>[];
    final NfcManagerReaderService service = NfcManagerReaderService(
      manager: manager,
      scanTimeout: const Duration(milliseconds: 100),
      tagInspector: (NfcTag tag, ScanSettings settings) async => _scan(),
    );

    await service.startScan(
      settings: const ScanSettings(),
      onScan: (NfcScan scan) async => delivered.complete(),
      onError: errors.add,
    );
    manager.discover();
    await delivered.future;
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(errors, isEmpty);
    expect(manager.stopCalls, 1);
  });

  test('iOS session error wins once during pending inspection', () async {
    final _FakeNfcManager manager = _FakeNfcManager();
    final Completer<NfcScan> inspection = Completer<NfcScan>();
    final Completer<void> inspectionStarted = Completer<void>();
    final List<NfcScan> scans = <NfcScan>[];
    final List<String> errors = <String>[];
    final NfcManagerReaderService service = NfcManagerReaderService(
      manager: manager,
      scanTimeout: const Duration(milliseconds: 100),
      tagInspector: (NfcTag tag, ScanSettings settings) {
        inspectionStarted.complete();
        return inspection.future;
      },
    );

    await service.startScan(
      settings: const ScanSettings(),
      onScan: (NfcScan scan) async => scans.add(scan),
      onError: errors.add,
    );
    manager.discover();
    await inspectionStarted.future;
    manager.failSession(
      const NfcReaderSessionErrorIos(
        code: NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled,
        message: 'Reader session cancelled',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 180));
    inspection.complete(_scan());
    await Future<void>.delayed(Duration.zero);

    expect(scans, isEmpty);
    expect(errors, <String>['Reader session cancelled']);
    expect(manager.stopCalls, 0);
  });

  test(
    'unconfirmed close suppresses scan success and automatic rearm',
    () async {
      final _FakeNfcManager manager = _FakeNfcManager()
        ..stopCompleter = Completer<void>();
      final List<NfcScan> scans = <NfcScan>[];
      final List<String> errors = <String>[];
      final NfcManagerReaderService service = NfcManagerReaderService(
        manager: manager,
        scanTimeout: const Duration(seconds: 1),
        sessionCloseTimeout: const Duration(milliseconds: 100),
        tagInspector: (NfcTag tag, ScanSettings settings) async => _scan(),
      );

      await service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async => scans.add(scan),
        onError: errors.add,
      );
      manager.discover();
      await Future<void>.delayed(const Duration(milliseconds: 180));

      expect(scans, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.single, contains('still closing'));
      expect(manager.startCalls, 1);
      expect(manager.stopCalls, 1);

      await expectLater(
        service.startScan(
          settings: const ScanSettings(),
          onScan: (NfcScan scan) async {},
          onError: (String message) {},
        ),
        throwsA(isA<StateError>()),
      );
      expect(manager.startCalls, 1);

      manager.stopCompleter!.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'unconfirmed native close is bounded and blocks a replacement session',
    () async {
      final _FakeNfcManager manager = _FakeNfcManager()
        ..stopCompleter = Completer<void>();
      final NfcManagerReaderService service = NfcManagerReaderService(
        manager: manager,
        scanTimeout: const Duration(seconds: 1),
        sessionCloseTimeout: const Duration(milliseconds: 100),
        tagInspector: (NfcTag tag, ScanSettings settings) async => _scan(),
      );

      await service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async {},
        onError: (String message) {},
      );
      await expectLater(
        service.stopScan().timeout(const Duration(seconds: 1)),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains('still closing'),
          ),
        ),
      );
      expect(manager.stopCalls, 1);

      await expectLater(
        service.startScan(
          settings: const ScanSettings(),
          onScan: (NfcScan scan) async {},
          onError: (String message) {},
        ),
        throwsA(isA<StateError>()),
      );
      expect(manager.startCalls, 1);

      manager.stopCompleter!.complete();
      await Future<void>.delayed(Duration.zero);
      manager.stopCompleter = null;
      await service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async {},
        onError: (String message) {},
      );
      expect(manager.startCalls, 2);
      await service.stopScan();
    },
  );

  test(
    'synchronous native close errors are treated as already invalidated',
    () async {
      final _FakeNfcManager manager = _FakeNfcManager()..throwOnStop = true;
      final NfcManagerReaderService service = NfcManagerReaderService(
        manager: manager,
        scanTimeout: const Duration(seconds: 1),
        tagInspector: (NfcTag tag, ScanSettings settings) async => _scan(),
      );

      await service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async {},
        onError: (String message) {},
      );
      await service.stopScan();
      expect(manager.stopCalls, 1);

      manager.throwOnStop = false;
      await service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async {},
        onError: (String message) {},
      );
      expect(manager.startCalls, 2);
      await service.stopScan();
    },
  );

  test(
    'explicit stop suppresses timeout and late inspection delivery',
    () async {
      final _FakeNfcManager manager = _FakeNfcManager();
      final Completer<NfcScan> inspection = Completer<NfcScan>();
      final Completer<void> inspectionStarted = Completer<void>();
      final List<NfcScan> scans = <NfcScan>[];
      final List<String> errors = <String>[];
      final NfcManagerReaderService service = NfcManagerReaderService(
        manager: manager,
        scanTimeout: const Duration(milliseconds: 100),
        tagInspector: (NfcTag tag, ScanSettings settings) {
          inspectionStarted.complete();
          return inspection.future;
        },
      );

      await service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async => scans.add(scan),
        onError: errors.add,
      );
      manager.discover();
      await inspectionStarted.future;
      await service.stopScan();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      inspection.complete(_scan());
      await Future<void>.delayed(Duration.zero);

      expect(manager.stopCalls, 1);
      expect(scans, isEmpty);
      expect(errors, isEmpty);
    },
  );
}

NfcScan _scan() {
  return NfcScan(
    id: 'scan-test',
    scannedAt: DateTime.utc(2026, 9, 6),
    platform: 'android',
    uidHex: '04:AA:BB:CC',
    uidFingerprint: 'a' * 64,
    identityStability: TagIdentityStability.stable,
    technologies: const <String>['NfcA'],
    details: const <String, String>{},
    ndefRecords: const [],
    warnings: const [],
  );
}

final class _FakeNfcManager extends NfcManager {
  void Function(NfcTag tag)? _onDiscovered;
  void Function(NfcReaderSessionErrorIos error)? _onSessionErrorIos;
  int startCalls = 0;
  int stopCalls = 0;
  Completer<void>? stopCompleter;
  bool throwOnStop = false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<NfcAvailability> checkAvailability() async => NfcAvailability.enabled;

  @override
  Future<void> startSession({
    required Set<NfcPollingOption> pollingOptions,
    required void Function(NfcTag tag) onDiscovered,
    String? alertMessageIos,
    bool invalidateAfterFirstReadIos = true,
    void Function(NfcReaderSessionErrorIos)? onSessionErrorIos,
    bool noPlatformSoundsAndroid = false,
  }) async {
    startCalls += 1;
    _onDiscovered = onDiscovered;
    _onSessionErrorIos = onSessionErrorIos;
  }

  @override
  Future<void> stopSession({String? alertMessageIos, String? errorMessageIos}) {
    stopCalls += 1;
    if (throwOnStop) {
      throw StateError('simulated synchronous close failure');
    }
    final Completer<void>? pending = stopCompleter;
    return pending?.future ?? Future<void>.value();
  }

  void discover() {
    _onDiscovered?.call(NfcTag(data: Object()));
  }

  void failSession(NfcReaderSessionErrorIos error) {
    _onSessionErrorIos?.call(error);
  }
}
