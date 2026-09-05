import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/domain/models/ndef_record_info.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/tag_identity_stability.dart';
import 'package:tagverity/presentation/pages/scan_detail_page.dart';

void main() {
  testWidgets('tag details tolerate narrow 200 percent text layout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(MaterialApp(home: ScanDetailPage(scan: _scan())));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tag details'), findsOneWidget);
    expect(find.text('REVIEW'), findsOneWidget);

    for (
      int index = 0;
      index < 30 && find.text('Show technical').evaluate().isEmpty;
      index++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -220));
      await tester.pumpAndSettle();
    }
    final Finder technicalButton = find.text('Show technical');
    expect(technicalButton, findsOneWidget);
    await tester.ensureVisible(technicalButton);
    await tester.pumpAndSettle();

    await tester.tap(technicalButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hide technical'), findsOneWidget);
    expect(find.text('NFC-A timeout'), findsOneWidget);

    for (
      int index = 0;
      index < 30 && find.textContaining('Record 1').evaluate().isEmpty;
      index++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -220));
      await tester.pumpAndSettle();
    }
    final Finder ndefRecord = find.textContaining('Record 1');
    expect(ndefRecord, findsOneWidget);
    await tester.ensureVisible(ndefRecord);
    await tester.pumpAndSettle();
    await tester.tap(ndefRecord);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Payload length'), findsOneWidget);
  });
}

NfcScan _scan() {
  return NfcScan(
    id: 'detail-scan',
    scannedAt: DateTime.utc(2026, 9, 5),
    platform: 'android',
    uidHex: '04:AA:BB:CC:DD:EE:FF',
    uidFingerprint:
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    identityStability: TagIdentityStability.stable,
    technologies: const <String>['NfcA', 'Ndef', 'IsoDep'],
    details: const <String, String>{
      'protocol': 'NFC-A / ISO 14443-3A',
      'nfca.atqa': '44:00',
      'nfca.sak': '0x20',
      'nfca.timeout': '618 ms',
      'nfca.maxTransceiveLength': '253 bytes',
      'ndef.supported': 'yes',
      'ndef.readStatus': 'error',
      'ndef.maxSize': '4096 bytes',
      'ndef.writable': 'no',
    },
    ndefRecords: const <NdefRecordInfo>[
      NdefRecordInfo(
        index: 0,
        typeNameFormat: 'wellKnown',
        type: 'T',
        identifierHex: '',
        payloadLength: 128,
        byteLength: 132,
        summary: 'A deliberately long NDEF summary that exercises wrapping on a narrow screen without relying on an emulator.',
        payloadPreviewHex: '00:01:02:03:04:05:06:07:08:09:0A:0B:0C:0D:0E:0F',
      ),
    ],
    warnings: const <String>[
      'Could not read standard NDEF because the tag moved before the operation completed.',
    ],
  );
}
