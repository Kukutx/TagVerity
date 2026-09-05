import '../../core/constants/app_constants.dart';
import '../models/diagnostic_event.dart';

final class DiagnosticsBuffer {
  List<DiagnosticEvent> _events = const <DiagnosticEvent>[];

  List<DiagnosticEvent> get events =>
      List<DiagnosticEvent>.unmodifiable(_events);

  void add(
    AppDiagnosticLevel level,
    String code,
    String message, {
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    final Map<String, Object?> sanitizedData = data.map(
      (String key, Object? value) =>
          MapEntry<String, Object?>(key, _sanitize(value)),
    );
    final DiagnosticEvent event = DiagnosticEvent(
      timestamp: DateTime.now(),
      level: level,
      code: code,
      message: _redact(message),
      data: Map<String, Object?>.unmodifiable(sanitizedData),
    );
    _events = <DiagnosticEvent>[..._events, event];
    if (_events.length > AppConstants.maximumDiagnosticEvents) {
      _events = _events
          .skip(_events.length - AppConstants.maximumDiagnosticEvents)
          .toList(growable: false);
    }
  }

  void clear() {
    _events = const <DiagnosticEvent>[];
  }

  Object? _sanitize(Object? value) {
    if (value == null || value is num || value is bool) {
      return value;
    }
    if (value is String) {
      return _redact(value);
    }
    if (value is Map) {
      return <String, Object?>{
        for (final MapEntry<Object?, Object?> entry in value.entries)
          _redact(entry.key.toString()): _sanitize(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map<Object?>(_sanitize).toList(growable: false);
    }
    return _redact(value.toString());
  }

  String _redact(String value) {
    return value
        .replaceAll(
          RegExp(r'\b(?:[0-9A-Fa-f]{2}:){3,}[0-9A-Fa-f]{2}\b'),
          '[redacted-hex-identifier]',
        )
        .replaceAll(RegExp(r'\b[0-9A-Fa-f]{8,}\b'), '[redacted-long-hex]');
  }
}
