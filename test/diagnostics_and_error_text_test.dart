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

  test('diagnostics bound strings collections and nesting depth', () {
    final DiagnosticsBuffer buffer = DiagnosticsBuffer();
    final Map<String, Object?> manyValues = <String, Object?>{
      for (int index = 0; index < 40; index++) 'key-$index': 'value-$index',
    };

    buffer.add(
      AppDiagnosticLevel.warning,
      'x' * 800,
      'm' * 800,
      data: <String, Object?>{
        'many': manyValues,
        'list': List<int>.generate(50, (int index) => index),
        'deep': <String, Object?>{
          'a': <String, Object?>{
            'b': <String, Object?>{
              'c': <String, Object?>{
                'd': <String, Object?>{'secret': 'should not be retained'},
              },
            },
          },
        },
      },
    );

    final DiagnosticEvent event = buffer.events.single;
    expect(event.code.runes.length, DiagnosticsBuffer.maximumStringCharacters);
    expect(
      event.message.runes.length,
      DiagnosticsBuffer.maximumStringCharacters,
    );
    expect((event.data['many'] as Map<String, Object?>).length, 20);
    expect((event.data['list'] as List<Object?>).length, 20);
    expect(jsonEncode(event.data), contains('[truncated-depth]'));
    expect(jsonEncode(event.data), isNot(contains('should not be retained')));
  });

  test('diagnostics nested sanitized data is immutable after retention', () {
    final DiagnosticsBuffer buffer = DiagnosticsBuffer();
    buffer.add(
      AppDiagnosticLevel.info,
      'snapshot',
      'snapshot test',
      data: <String, Object?>{
        'nested': <String, Object?>{
          'values': <Object?>['safe', 42],
        },
      },
    );

    final DiagnosticEvent event = buffer.events.single;
    final Map<String, Object?> nested =
        event.data['nested']! as Map<String, Object?>;
    final List<Object?> values = nested['values']! as List<Object?>;
    final String before = jsonEncode(event.toJson());

    expect(
      () => nested['new'] = 'late mutation',
      throwsA(isA<UnsupportedError>()),
    );
    expect(() => values.add('late mutation'), throwsA(isA<UnsupportedError>()));
    expect(jsonEncode(event.toJson()), before);
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

  test('ErrorText bounds external text and removes control characters', () {
    final String cleaned = ErrorText.clean(
      PlatformException(
        code: 'native',
        message: '  first\nsecond\t${'x' * 700}\u0000\u009Btail  ',
      ),
    );

    expect(cleaned.runes.length, ErrorText.maximumCharacters);
    expect(cleaned, startsWith('first second '));
    expect(cleaned, isNot(contains('\n')));
    expect(cleaned, isNot(contains('\t')));
    expect(cleaned, isNot(contains('\u0000')));
    expect(cleaned, isNot(contains('\u009B')));
    expect(cleaned, endsWith('…'));
    expect(ErrorText.clean('\n\t'), 'Unexpected error.');
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
