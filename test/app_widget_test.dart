import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/app.dart';
import 'package:tagverity/data/nfc/nfc_reader_service.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/nfc_support_status.dart';
import 'package:tagverity/domain/models/scan_settings.dart';
import 'package:tagverity/domain/models/tag_identity_stability.dart';
import 'package:tagverity/domain/repositories/scan_history_repository.dart';
import 'package:tagverity/domain/services/export_service.dart';
import 'package:tagverity/presentation/controllers/nfc_scan_controller.dart';

void main() {
  testWidgets('app navigates across the four core surfaces', (
    WidgetTester tester,
  ) async {
    final NfcScanController controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TagVerityApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Inspect an NFC tag'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.playlist_add_check_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Batch check'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Scan history'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Privacy & history'), findsOneWidget);
    expect(find.text('Scan timeout'), findsNothing);
    expect(find.text('Maximum history'), findsNothing);
  });
  testWidgets('scan button reflects scanning state without an emulator', (
    WidgetTester tester,
  ) async {
    final NfcScanController controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TagVerityApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan NFC tag'));
    await tester.pump();
    expect(find.text('Stop scanning'), findsOneWidget);
    await tester.tap(find.text('Stop scanning'));
    await tester.pumpAndSettle();
    expect(find.text('Scan NFC tag'), findsOneWidget);
  });
  testWidgets('controller errors are visible from the current tab', (
    WidgetTester tester,
  ) async {
    final NfcScanController controller = await _controller(
      reader: _WidgetReader(scanError: 'Widget scan failed'),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(TagVerityApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.playlist_add_check_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start continuous batch'));
    await tester.pumpAndSettle();
    expect(find.text('Widget scan failed'), findsOneWidget);
    expect(find.byTooltip('Dismiss error'), findsOneWidget);
  });
  testWidgets('sensitive retention requires confirmation', (
    WidgetTester tester,
  ) async {
    final _WidgetRepository repository = _WidgetRepository();
    final NfcScanController controller = await _controller(
      repository: repository,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(TagVerityApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save raw UID in history'));
    await tester.pumpAndSettle();
    expect(find.text('Save raw UID?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.settings.saveRawUidInHistory, isFalse);
    await tester.tap(find.text('Save raw UID in history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
    expect(controller.settings.saveRawUidInHistory, isTrue);
    expect(repository.settings.saveRawUidInHistory, isTrue);
  });
  testWidgets('recovery toggles do not claim hidden history was scrubbed', (
    WidgetTester tester,
  ) async {
    final _WidgetRepository repository = _WidgetRepository(
      failLoadSettings: true,
      initialHistory: <NfcScan>[_stressScan()],
    );
    final NfcScanController controller = await _controller(
      repository: repository,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(TagVerityApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    final Finder rawUidToggle = find.text('Save raw UID in history');
    await tester.scrollUntilVisible(rawUidToggle, 200);
    await tester.pumpAndSettle();
    await tester.tap(rawUidToggle);
    await tester.pumpAndSettle();
    expect(find.text('Save raw UID?'), findsOneWidget);
    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
    expect(controller.settings.saveRawUidInHistory, isTrue);
    expect(controller.privacySettingsRecoveryRequired, isTrue);

    await tester.tap(rawUidToggle);
    await tester.pumpAndSettle();

    expect(controller.settings.saveRawUidInHistory, isFalse);
    expect(controller.privacySettingsRecoveryRequired, isTrue);
    expect(controller.errorMessage, contains('still hidden'));
    expect(
      find.text('Setting disabled; matching saved data was removed'),
      findsNothing,
    );
  });

  testWidgets(
    'settings recovery flow stays usable on a narrow large-text screen',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final _WidgetRepository repository = _WidgetRepository(
        failLoadSettings: true,
        initialHistory: <NfcScan>[_stressScan()],
      );
      final NfcScanController controller = await _controller(
        repository: repository,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(TagVerityApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();

      expect(controller.privacySettingsRecoveryRequired, isTrue);
      expect(controller.history, isEmpty);

      final Finder recoveryMessage = find.textContaining(
        'Saved privacy settings could not be read',
      );
      await tester.scrollUntilVisible(recoveryMessage, 200);
      await tester.pumpAndSettle();
      expect(recoveryMessage, findsOneWidget);

      final Finder applyButton = find.text(
        'Apply privacy settings to saved history',
      );
      await tester.scrollUntilVisible(applyButton, 200);
      await tester.pumpAndSettle();
      expect(applyButton, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(controller.privacySettingsRecoveryRequired, isFalse);
      expect(
        find.textContaining('Saved history recovered using'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('core UI fits a narrow phone surface without exceptions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final NfcScanController controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TagVerityApp(controller: controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Scan NFC tag'), findsOneWidget);
  });
  testWidgets('core UI tolerates 200 percent text scaling', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final NfcScanController controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TagVerityApp(controller: controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Inspect an NFC tag'), findsOneWidget);
  });
  testWidgets('all core tabs tolerate narrow 200 percent text layout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final NfcScanController controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TagVerityApp(controller: controller));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Inspect should not overflow',
    );

    for (final String tab in <String>['Batch', 'History', 'Settings']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '$tab should not overflow',
      );
    }
  });

  testWidgets(
    'populated core results tolerate narrow 200 percent text layout',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final NfcScanController controller = await _controller(
        reader: _WidgetReader(scan: _stressScan()),
      );
      addTearDown(controller.dispose);
      await controller.startScan();
      controller.startBatchSession();
      await controller.startBatchScan();
      await tester.pumpWidget(TagVerityApp(controller: controller));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Latest scan should not overflow',
      );

      for (final String tab in <String>['Batch', 'History']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Populated $tab should not overflow',
        );
      }
    },
  );

  testWidgets('dark mode renders the core shell without exceptions', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final NfcScanController controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TagVerityApp(controller: controller));
    await tester.pumpAndSettle();
    final BuildContext context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}

Future<NfcScanController> _controller({
  _WidgetReader? reader,
  _WidgetRepository? repository,
}) async {
  final NfcScanController controller = NfcScanController(
    readerService: reader ?? _WidgetReader(),
    repository: repository ?? _WidgetRepository(),
    exportService: _WidgetExportService(),
  );
  await controller.initialize();
  return controller;
}

NfcScan _stressScan() {
  return NfcScan(
    id: 'scan-stress',
    scannedAt: DateTime.utc(2026, 9, 5),
    platform: 'android',
    uidFingerprint:
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    identityStability: TagIdentityStability.sessionOnly,
    technologies: const <String>['NfcA', 'IsoDep'],
    details: const <String, String>{
      'ndef.supported': 'no',
      'ndef.readStatus': 'not-supported',
    },
    ndefRecords: const [],
    warnings: const <String>[],
  );
}

final class _WidgetReader implements NfcReaderService {
  _WidgetReader({this.scanError, this.scan});
  final String? scanError;
  final NfcScan? scan;
  @override
  Future<NfcSupportStatus> checkAvailability() async =>
      NfcSupportStatus.enabled;
  @override
  Future<void> startScan({
    required ScanSettings settings,
    required ScanResultCallback onScan,
    required ScanErrorCallback onError,
  }) async {
    if (scanError case final String message) {
      onError(message);
      return;
    }
    if (scan case final NfcScan value) {
      await onScan(value);
    }
  }

  @override
  Future<void> stopScan() async {}
}

final class _WidgetRepository implements ScanHistoryRepository {
  _WidgetRepository({
    this.failLoadSettings = false,
    List<NfcScan> initialHistory = const <NfcScan>[],
  }) : history = List<NfcScan>.of(initialHistory);

  final bool failLoadSettings;
  List<NfcScan> history;
  ScanSettings settings = const ScanSettings();

  @override
  Future<void> clearHistory() async {
    history = <NfcScan>[];
  }

  @override
  Future<List<NfcScan>> loadHistory() async => List<NfcScan>.of(history);

  @override
  Future<ScanSettings> loadSettings() async {
    if (failLoadSettings) {
      throw const FormatException('corrupt settings');
    }
    return settings;
  }

  @override
  Future<void> saveHistory(List<NfcScan> scans) async {
    history = List<NfcScan>.of(scans);
  }

  @override
  Future<void> saveSettings(ScanSettings value) async {
    settings = value;
  }
}

final class _WidgetExportService implements ExportService {
  @override
  Future<void> shareTextFile({
    required String filename,
    required String content,
    required String mimeType,
    required String subject,
  }) async {}
}
