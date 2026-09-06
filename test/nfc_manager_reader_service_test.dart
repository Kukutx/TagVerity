import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:tagverity/data/nfc/nfc_manager_reader_service.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/nfc_support_status.dart';
import 'package:tagverity/domain/models/scan_settings.dart';
import 'package:tagverity/domain/models/tag_identity_stability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'availability maps native states and propagates platform failures',
    () async {
      final _FakeNfcManager manager = _FakeNfcManager();
      final NfcManagerReaderService service = NfcManagerReaderService(
        manager: manager,
      );

      expect(await service.checkAvailability(), NfcSupportStatus.enabled);
      manager.availability = NfcAvailability.disabled;
      expect(await service.checkAvailability(), NfcSupportStatus.disabled);
      manager.availability = NfcAvailability.unsupported;
      expect(await service.checkAvailability(), NfcSupportStatus.unsupported);

      manager.availabilityError = StateError('native availability failed');
      await expectLater(
        service.checkAvailability(),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains('native availability failed'),
          ),
        ),
      );
    },
  );

  test('availability timeout propagates to the controller boundary', () async {
    final _FakeNfcManager manager = _FakeNfcManager()
      ..availabilityFuture = Completer<NfcAvailability>().future;
    final NfcManagerReaderService service = NfcManagerReaderService(
      manager: manager,
      availabilityCheckTimeout: const Duration(milliseconds: 100),
    );

    await expectLater(
      service.checkAvailability(),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('native session start timeout blocks replacement until late cleanup settles', () async {
    final _FakeNfcManager manager = _FakeNfcManager()
      ..startCompleter = Completer<void>()
      ..stopCompleter = Completer<void>();
    final NfcManagerReaderService service = NfcManagerReaderService(
      manager: manager,
      sessionStartTimeout: const Duration(milliseconds: 100),
      sessionCloseTimeout: const Duration(milliseconds: 100),
      scanTimeout: const Duration(seconds: 1),
      tagInspector: (NfcTag tag, ScanSettings settings) async => _scan(),
    );

    await expectLater(
      service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async {},
        onError: (String message) {},
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('start timed out'),
        ),
      ),
    );
    expect(manager.startCalls, 1);
    expect(manager.stopCalls, 0);

    await expectLater(
      service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async {},
        onError: (String message) {},
      ),
      throwsA(isA<StateError>()),
    );
    expect(manager.startCalls, 1);

    manager.startCompleter!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(manager.stopCalls, 1);

    await expectLater(
      service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async {},
        onError: (String message) {},
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('still closing'),
        ),
      ),
    );
    expect(manager.startCalls, 1);

    manager.stopCompleter!.complete();
    await Future<void>.delayed(Duration.zero);
    manager
      ..startCompleter = null
      ..stopCompleter = null;
    await service.startScan(
      settings: const ScanSettings(),
      onScan: (NfcScan scan) async {},
      onError: (String message) {},
    );
    expect(manager.startCalls, 2);
    await service.stopScan();
  });

  test(
    'explicit stop abandons a pending native start and cleans it later',
    () async {
      final _FakeNfcManager manager = _FakeNfcManager()
        ..startCompleter = Completer<void>();
      final NfcManagerReaderService service = NfcManagerReaderService(
        manager: manager,
        sessionStartTimeout: const Duration(seconds: 1),
        scanTimeout: const Duration(seconds: 1),
        tagInspector: (NfcTag tag, ScanSettings settings) async => _scan(),
      );

      final Future<void> starting = service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async {},
        onError: (String message) {},
      );
      await Future<void>.delayed(Duration.zero);
      await service.stopScan().timeout(const Duration(seconds: 1));
      expect(manager.stopCalls, 0);

      await expectLater(
        service.startScan(
          settings: const ScanSettings(),
          onScan: (NfcScan scan) async {},
          onError: (String message) {},
        ),
        throwsA(isA<StateError>()),
      );

      manager.startCompleter!.complete();
      await starting;
      await Future<void>.delayed(Duration.zero);
      expect(manager.stopCalls, 1);

      manager.startCompleter = null;
      await Future<void>.delayed(Duration.zero);
      await service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async {},
        onError: (String message) {},
      );
      expect(manager.startCalls, 2);
      await service.stopScan();
    },
  );

  test('late native start failure releases the pending-start lock', () async {
    final _FakeNfcManager manager = _FakeNfcManager()
      ..startCompleter = Completer<void>();
    final NfcManagerReaderService service = NfcManagerReaderService(
      manager: manager,
      sessionStartTimeout: const Duration(milliseconds: 100),
      tagInspector: (NfcTag tag, ScanSettings settings) async => _scan(),
    );

    await expectLater(
      service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async {},
        onError: (String message) {},
      ),
      throwsA(isA<StateError>()),
    );
    manager.startCompleter!.completeError(StateError('late start failure'));
    await Future<void>.delayed(Duration.zero);
    manager.startCompleter = null;

    await service.startScan(
      settings: const ScanSettings(),
      onScan: (NfcScan scan) async {},
      onError: (String message) {},
    );
    expect(manager.startCalls, 2);
    expect(manager.stopCalls, 0);
    await service.stopScan();
  });

  test(
    'iOS session error during pending start triggers one late cleanup',
    () async {
      final _FakeNfcManager manager = _FakeNfcManager()
        ..startCompleter = Completer<void>();
      final List<String> errors = <String>[];
      final NfcManagerReaderService service = NfcManagerReaderService(
        manager: manager,
        sessionStartTimeout: const Duration(seconds: 1),
        tagInspector: (NfcTag tag, ScanSettings settings) async => _scan(),
      );

      final Future<void> starting = service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async {},
        onError: errors.add,
      );
      await Future<void>.delayed(Duration.zero);
      manager.failSession(
        const NfcReaderSessionErrorIos(
          code:
              NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled,
          message: 'Reader session cancelled during start',
        ),
      );
      expect(errors, <String>['Reader session cancelled during start']);
      expect(manager.stopCalls, 0);

      manager.startCompleter!.complete();
      await starting;
      await Future<void>.delayed(Duration.zero);
      expect(manager.stopCalls, 1);
      expect(errors, hasLength(1));

      manager.startCompleter = null;
      await service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async {},
        onError: (String message) {},
      );
      expect(manager.startCalls, 2);
      await service.stopScan();
    },
  );

  test('synchronous native start errors remain recoverable', () async {
    final _FakeNfcManager manager = _FakeNfcManager()..throwOnStart = true;
    final NfcManagerReaderService service = NfcManagerReaderService(
      manager: manager,
      tagInspector: (NfcTag tag, ScanSettings settings) async => _scan(),
    );

    await expectLater(
      service.startScan(
        settings: const ScanSettings(),
        onScan: (NfcScan scan) async {},
        onError: (String message) {},
      ),
      throwsA(isA<StateError>()),
    );
    manager.throwOnStart = false;
    await service.startScan(
      settings: const ScanSettings(),
      onScan: (NfcScan scan) async {},
      onError: (String message) {},
    );
    expect(manager.startCalls, 2);
    await service.stopScan();
  });

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
  Completer<void>? startCompleter;
  Completer<void>? stopCompleter;
  bool throwOnStart = false;
  bool throwOnStop = false;
  NfcAvailability availability = NfcAvailability.enabled;
  Future<NfcAvailability>? availabilityFuture;
  Object? availabilityError;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<NfcAvailability> checkAvailability() {
    final Object? error = availabilityError;
    if (error != null) {
      return Future<NfcAvailability>.error(error);
    }
    return availabilityFuture ?? Future<NfcAvailability>.value(availability);
  }

  @override
  Future<void> startSession({
    required Set<NfcPollingOption> pollingOptions,
    required void Function(NfcTag tag) onDiscovered,
    String? alertMessageIos,
    bool invalidateAfterFirstReadIos = true,
    void Function(NfcReaderSessionErrorIos)? onSessionErrorIos,
    bool noPlatformSoundsAndroid = false,
  }) {
    startCalls += 1;
    _onDiscovered = onDiscovered;
    _onSessionErrorIos = onSessionErrorIos;
    if (throwOnStart) {
      throw StateError('simulated synchronous start failure');
    }
    final Completer<void>? pending = startCompleter;
    return pending?.future ?? Future<void>.value();
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
