enum AppDiagnosticLevel { info, warning, error }

class DiagnosticEvent {
  const DiagnosticEvent({
    required this.timestamp,
    required this.level,
    required this.code,
    required this.message,
    this.data = const <String, Object?>{},
  });

  final DateTime timestamp;
  final AppDiagnosticLevel level;
  final String code;
  final String message;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => <String, Object?>{
    'timestamp': timestamp.toUtc().toIso8601String(),
    'level': level.name,
    'code': code,
    'message': message,
    'data': data,
  };
}
