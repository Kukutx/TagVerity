import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/app.dart';
import 'package:tagverity/data/nfc/nfc_reader_service.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/nfc_support_status.dart';
import 'package:tagverity/domain/models/scan_settings.dart';
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

final class _WidgetReader implements NfcReaderService {
  _WidgetReader({this.scanError});
  final String? scanError;
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
    }
  }

  @override
  Future<void> stopScan() async {}
}

final class _WidgetRepository implements ScanHistoryRepository {
  ScanSettings settings = const ScanSettings();
  @override
  Future<void> clearHistory() async {}
  @override
  Future<List<NfcScan>> loadHistory() async => const <NfcScan>[];
  @override
  Future<ScanSettings> loadSettings() async => settings;
  @override
  Future<void> saveHistory(List<NfcScan> scans) async {}
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
