import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/core/utils/error_text.dart';
import 'package:tagverity/domain/models/diagnostic_event.dart';
import 'package:tagverity/domain/services/diagnostics_buffer.dart';

void main() {
  test('diagnostics recursively redact identifiers in nested data', () {
    final DiagnosticsBuffer buffer = DiagnosticsBuffer();

    buffer.add(
      AppDiagnosticLevel.error,
      'test.redaction',
      'UID 04:AA:BB:CC:DD:EE:FF',
      data: <String, Object?>{
        'nested': <String, Object?>{
          'uid': '04:11:22:33:44:55:66',
          'compactUid': '04AABBCC',
          'values': <Object?>[
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            42,
            true,
          ],
        },
      },
    );

    final DiagnosticEvent event = buffer.events.single;
    final String encoded = jsonEncode(event.toJson());
    expect(encoded, isNot(contains('04:AA:BB:CC:DD:EE:FF')));
    expect(encoded, isNot(contains('04:11:22:33:44:55:66')));
    expect(encoded, isNot(contains('04AABBCC')));
    expect(encoded, isNot(contains('0123456789abcdef0123456789abcdef')));
    expect(encoded, contains('[redacted-hex-identifier]'));
    expect(encoded, contains('[redacted-long-hex]'));
    expect(encoded, contains('42'));
  });

  test('diagnostics cap retains only the newest events', () {
    final DiagnosticsBuffer buffer = DiagnosticsBuffer();
    for (int index = 0; index < 120; index++) {
      buffer.add(AppDiagnosticLevel.info, 'event.$index', 'event $index');
    }
    expect(buffer.events, hasLength(100));
    expect(buffer.events.first.code, 'event.20');
    expect(buffer.events.last.code, 'event.119');
  });

  test('ErrorText exposes clean platform and state messages', () {
    expect(
      ErrorText.clean(
        PlatformException(code: 'clipboard', message: 'Clipboard unavailable'),
      ),
      'Clipboard unavailable',
    );
    expect(
      ErrorText.clean(PlatformException(code: 'share_failed')),
      'share_failed',
    );
    expect(ErrorText.clean(StateError('disk unavailable')), 'disk unavailable');
    expect(
      ErrorText.clean(const FormatException('invalid saved data')),
      'invalid saved data',
    );
  });
}
