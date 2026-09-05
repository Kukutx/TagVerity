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
      (String key, Object? value) => MapEntry<String, Object?>(
        key,
        value is String ? _redact(value) : value,
      ),
    );
    final DiagnosticEvent event = DiagnosticEvent(
      timestamp: DateTime.now(),
      level: level,
      code: code,
      message: _redact(message),
      data: sanitizedData,
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

  String _redact(String value) {
    return value
        .replaceAll(
          RegExp(r'\b(?:[0-9A-Fa-f]{2}:){3,}[0-9A-Fa-f]{2}\b'),
          '[redacted-hex-identifier]',
        )
        .replaceAll(RegExp(r'\b[0-9A-Fa-f]{32,}\b'), '[redacted-long-hex]');
  }
}
