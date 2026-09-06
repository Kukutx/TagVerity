import '../../core/constants/app_constants.dart';
import '../models/diagnostic_event.dart';

final class DiagnosticsBuffer {
  static const int maximumStringCharacters = 500;
  static const int maximumCollectionItems = 20;
  static const int maximumNestingDepth = 4;

  List<DiagnosticEvent> _events = const <DiagnosticEvent>[];

  List<DiagnosticEvent> get events =>
      List<DiagnosticEvent>.unmodifiable(_events);

  void add(
    AppDiagnosticLevel level,
    String code,
    String message, {
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    final Map<String, Object?> sanitizedData = <String, Object?>{};
    int dataCount = 0;
    for (final MapEntry<String, Object?> entry in data.entries) {
      if (dataCount >= maximumCollectionItems) {
        break;
      }
      sanitizedData[_redactAndBound(entry.key)] = _sanitize(entry.value, 0);
      dataCount++;
    }
    final DiagnosticEvent event = DiagnosticEvent(
      timestamp: DateTime.now(),
      level: level,
      code: _redactAndBound(code),
      message: _redactAndBound(message),
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

  Object? _sanitize(Object? value, int depth) {
    if (value == null || value is num || value is bool) {
      return value;
    }
    if (value is String) {
      return _redactAndBound(value);
    }
    if (depth >= maximumNestingDepth) {
      return '[truncated-depth]';
    }
    if (value is Map) {
      final Map<String, Object?> result = <String, Object?>{};
      int count = 0;
      for (final MapEntry<Object?, Object?> entry in value.entries) {
        if (count >= maximumCollectionItems) {
          break;
        }
        result[_redactAndBound(_safeToString(entry.key))] = _sanitize(
          entry.value,
          depth + 1,
        );
        count++;
      }
      return Map<String, Object?>.unmodifiable(result);
    }
    if (value is Iterable) {
      final List<Object?> result = <Object?>[];
      try {
        for (final Object? item in value) {
          if (result.length >= maximumCollectionItems) {
            break;
          }
          result.add(_sanitize(item, depth + 1));
        }
      } on Object {
        result.add('[unavailable-item]');
      }
      return List<Object?>.unmodifiable(result);
    }
    return _redactAndBound(_safeToString(value));
  }

  String _safeToString(Object? value) {
    try {
      return value.toString();
    } on Object {
      return '[unavailable-value]';
    }
  }

  String _redactAndBound(String value) {
    final String redacted = value
        .replaceAll(
          RegExp(r'\b(?:[0-9A-Fa-f]{2}:){3,}[0-9A-Fa-f]{2}\b'),
          '[redacted-hex-identifier]',
        )
        .replaceAll(RegExp(r'\b[0-9A-Fa-f]{8,}\b'), '[redacted-long-hex]');
    final List<int> runes = redacted.runes.toList(growable: false);
    if (runes.length <= maximumStringCharacters) {
      return redacted;
    }
    return '${String.fromCharCodes(runes.take(maximumStringCharacters - 1))}…';
  }
}
