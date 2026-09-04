import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/byte_utils.dart';
import '../../data/nfc/nfc_reader_service.dart';
import '../../domain/models/diagnostic_event.dart';
import '../../domain/models/ndef_record_info.dart';
import '../../domain/models/nfc_scan.dart';
import '../../domain/models/nfc_support_status.dart';
import '../../domain/models/scan_settings.dart';
import '../../domain/models/tag_assessment.dart';
import '../../domain/models/tag_fact_catalog.dart';
import '../../domain/repositories/scan_history_repository.dart';
import '../../domain/services/export_service.dart';
import '../../domain/services/tag_assessor.dart';

final class NfcScanController extends ChangeNotifier
    with WidgetsBindingObserver {
  factory NfcScanController({
    required NfcReaderService readerService,
    required ScanHistoryRepository repository,
    required ExportService exportService,
  }) {
    return NfcScanController._(readerService, repository, exportService);
  }

  NfcScanController._(
    this._readerService,
    this._repository,
    this._exportService,
  ) {
    WidgetsBinding.instance.addObserver(this);
  }

  final NfcReaderService _readerService;
  final ScanHistoryRepository _repository;
  final ExportService _exportService;

  NfcSupportStatus _supportStatus = NfcSupportStatus.unknown;
  ScanSettings _settings = const ScanSettings();
  List<NfcScan> _history = const <NfcScan>[];
  List<DiagnosticEvent> _diagnosticEvents = const <DiagnosticEvent>[];
  List<NfcScan> _batchScans = const <NfcScan>[];
  NfcScan? _currentScan;
  String? _errorMessage;
  bool _initialized = false;
  bool _isScanning = false;
  bool _disposed = false;
  bool _batchSessionActive = false;
  bool _captureNextScanInBatch = false;
  DateTime? _batchStartedAt;

  NfcSupportStatus get supportStatus => _supportStatus;
  ScanSettings get settings => _settings;
  List<NfcScan> get history => List<NfcScan>.unmodifiable(_history);
  List<DiagnosticEvent> get diagnosticEvents =>
      List<DiagnosticEvent>.unmodifiable(_diagnosticEvents);
  List<NfcScan> get batchScans => List<NfcScan>.unmodifiable(_batchScans);
  NfcScan? get currentScan => _currentScan;
  String? get errorMessage => _errorMessage;
  bool get initialized => _initialized;
  bool get isScanning => _isScanning;
  bool get batchSessionActive => _batchSessionActive;
  DateTime? get batchStartedAt => _batchStartedAt;

  TagAssessment? get currentAssessment =>
      _currentScan == null ? null : TagAssessor.assess(_currentScan!);

  Set<String> get batchDuplicateFingerprints {
    final Map<String, int> counts = <String, int>{};
    for (final NfcScan scan in _batchScans.where(
      (NfcScan item) => item.hasComparableIdentity,
    )) {
      counts.update(
        scan.uidFingerprint,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return counts.entries
        .where((MapEntry<String, int> entry) => entry.value > 1)
        .map((MapEntry<String, int> entry) => entry.key)
        .toSet();
  }

  int get batchComparableCount =>
      _batchScans.where((NfcScan scan) => scan.hasComparableIdentity).length;

  int get batchSessionOnlyCount =>
      _batchScans.where((NfcScan scan) => !scan.hasComparableIdentity).length;

  int get batchUniqueCount => _batchScans
      .where((NfcScan scan) => scan.hasComparableIdentity)
      .map((NfcScan scan) => scan.uidFingerprint)
      .toSet()
      .length;

  int get batchReviewCount => _batchScans.where((NfcScan scan) {
    return TagAssessor.assess(scan).status == TagAssessmentStatus.review;
  }).length;

  int get batchLimitedCount => _batchScans.where((NfcScan scan) {
    return TagAssessor.assess(scan).status == TagAssessmentStatus.limited;
  }).length;

  int get batchHealthyCount => _batchScans.where((NfcScan scan) {
    return TagAssessor.assess(scan).status == TagAssessmentStatus.healthy;
  }).length;

  bool get batchAtCapacity =>
      _batchScans.length >= AppConstants.maximumBatchScans;

  Future<void> initialize() async {
    _addDiagnostic(
      AppDiagnosticLevel.info,
      'app.initialize.start',
      'Initializing TagVerity',
    );
    try {
      final ScanSettings settings = await _repository.loadSettings();
      final List<NfcScan> history = await _repository.loadHistory();
      _settings = settings;
      _history = history.take(settings.historyLimit).toList(growable: false);
    } on Object catch (error) {
      _errorMessage = 'Could not load local data: ${_cleanError(error)}';
      _addDiagnostic(
        AppDiagnosticLevel.error,
        'storage.initialize.failed',
        _errorMessage!,
      );
    }
    await refreshAvailability();
    _initialized = true;
    _addDiagnostic(
      AppDiagnosticLevel.info,
      'app.initialize.complete',
      'TagVerity initialized',
      data: <String, Object?>{'historyCount': _history.length},
    );
    _notify();
  }

  Future<void> refreshAvailability() async {
    final NfcSupportStatus previous = _supportStatus;
    _supportStatus = await _readerService.checkAvailability();
    if (_supportStatus != previous) {
      _addDiagnostic(
        AppDiagnosticLevel.info,
        'nfc.availability.changed',
        'NFC availability changed',
        data: <String, Object?>{'status': _supportStatus.name},
      );
    }
    _notify();
  }

  Future<void> startScan({bool addToBatch = false}) async {
    if (_isScanning) {
      return;
    }
    _captureNextScanInBatch = addToBatch;
    _errorMessage = null;
    await refreshAvailability();
    if (_supportStatus != NfcSupportStatus.enabled) {
      _captureNextScanInBatch = false;
      _errorMessage = switch (_supportStatus) {
        NfcSupportStatus.disabled =>
          'Turn on NFC in system settings and try again.',
        NfcSupportStatus.unsupported =>
          'This device does not support NFC tag reading.',
        _ => 'TagVerity could not confirm NFC availability.',
      };
      _notify();
      return;
    }

    _isScanning = true;
    _addDiagnostic(
      AppDiagnosticLevel.info,
      'nfc.scan.start',
      addToBatch ? 'Starting batch NFC scan' : 'Starting NFC scan',
      data: <String, Object?>{
        'timeoutSeconds': _settings.scanTimeoutSeconds,
        'readNdef': _settings.readNdef,
        'batch': addToBatch,
      },
    );
    _notify();

    try {
      await _readerService.startScan(
        settings: _settings,
        onScan: _handleScan,
        onError: (String message) {
          _captureNextScanInBatch = false;
          _isScanning = false;
          _errorMessage = message;
          _addDiagnostic(AppDiagnosticLevel.error, 'nfc.scan.failed', message);
          _notify();
        },
      );
    } on Object catch (error) {
      _captureNextScanInBatch = false;
      _isScanning = false;
      _errorMessage ??= 'Could not start scanning: ${_cleanError(error)}';
      _addDiagnostic(
        AppDiagnosticLevel.error,
        'nfc.scan.start.failed',
        _errorMessage!,
      );
      _notify();
    }
  }

  Future<void> startBatchScan() async {
    if (batchAtCapacity) {
      _errorMessage =
          'This batch reached the ${AppConstants.maximumBatchScans}-scan limit. Finish or clear it before scanning more tags.';
      _addDiagnostic(
        AppDiagnosticLevel.warning,
        'batch.capacity.reached',
        _errorMessage!,
        data: <String, Object?>{'limit': AppConstants.maximumBatchScans},
      );
      _notify();
      return;
    }
    if (!_batchSessionActive) {
      startBatchSession();
    }
    await startScan(addToBatch: true);
  }

  void startBatchSession() {
    if (_batchSessionActive) {
      return;
    }
    _batchSessionActive = true;
    _batchScans = const <NfcScan>[];
    _batchStartedAt = DateTime.now();
    _addDiagnostic(
      AppDiagnosticLevel.info,
      'batch.start',
      'Batch session started',
    );
    _notify();
  }

  void finishBatchSession() {
    _batchSessionActive = false;
    _captureNextScanInBatch = false;
    _addDiagnostic(
      AppDiagnosticLevel.info,
      'batch.finish',
      'Batch session finished',
      data: <String, Object?>{
        'scanCount': _batchScans.length,
        'uniqueCount': batchUniqueCount,
        'duplicateFingerprints': batchDuplicateFingerprints.length,
      },
    );
    _notify();
  }

  Future<void> clearBatchSession() async {
    if (_isScanning && _captureNextScanInBatch) {
      await stopScan();
    }
    _batchSessionActive = false;
    _captureNextScanInBatch = false;
    _batchScans = const <NfcScan>[];
    _batchStartedAt = null;
    _notify();
  }

  Future<void> stopScan() async {
    final bool wasScanning = _isScanning;
    try {
      await _readerService.stopScan();
      if (wasScanning) {
        _addDiagnostic(
          AppDiagnosticLevel.info,
          'nfc.scan.stop',
          'NFC scan stopped',
        );
      }
    } on Object catch (error) {
      _errorMessage = 'Could not stop NFC scanning: ${_cleanError(error)}';
      _addDiagnostic(
        AppDiagnosticLevel.error,
        'nfc.scan.stop.failed',
        _errorMessage!,
      );
    } finally {
      _captureNextScanInBatch = false;
      _isScanning = false;
      _notify();
    }
  }

  Future<void> _handleScan(NfcScan scan) async {
    final bool addToBatch = _captureNextScanInBatch;
    _captureNextScanInBatch = false;
    _currentScan = scan;
    _isScanning = false;
    _errorMessage = null;

    if (addToBatch && !batchAtCapacity) {
      _batchScans = <NfcScan>[..._batchScans, scan].toList(growable: false);
    }

    final NfcScan persisted = scan.copyWith(
      uidHex: _settings.saveRawUidInHistory ? scan.uidHex : null,
      details: _settings.saveTechnicalIdentifiersInHistory
          ? scan.details
          : TagFactCatalog.privacyScrubbedDetails(scan.details),
      ndefRecords: _settings.saveNdefInHistory
          ? scan.ndefRecords
          : const <NdefRecordInfo>[],
    );
    _history = <NfcScan>[
      persisted,
      ..._history.where((NfcScan item) => item.id != persisted.id),
    ].take(_settings.historyLimit).toList(growable: false);

    _addDiagnostic(
      AppDiagnosticLevel.info,
      'nfc.scan.complete',
      'NFC tag read completed',
      data: <String, Object?>{
        'platform': scan.platform,
        'technologyCount': scan.technologies.length,
        'detailCount': scan.details.length,
        'ndefRecordCount': scan.ndefRecords.length,
        'warningCount': scan.warnings.length,
        'batch': addToBatch,
      },
    );
    _notify();
    try {
      await _repository.saveHistory(_history);
    } on Object catch (error) {
      _errorMessage = 'Could not save scan history: ${_cleanError(error)}';
      _addDiagnostic(
        AppDiagnosticLevel.error,
        'storage.history.save.failed',
        _errorMessage!,
      );
      _notify();
    }
  }

  Future<void> updateSettings(ScanSettings settings) async {
    _settings = settings;
    final bool historyTrimmed = _history.length > settings.historyLimit;
    if (historyTrimmed) {
      _history = _history.take(settings.historyLimit).toList(growable: false);
    }
    _addDiagnostic(
      AppDiagnosticLevel.info,
      'settings.updated',
      'Settings updated',
      data: <String, Object?>{
        'readNdef': settings.readNdef,
        'platformSounds': settings.platformSounds,
        'saveRawUidInHistory': settings.saveRawUidInHistory,
        'saveNdefInHistory': settings.saveNdefInHistory,
        'saveTechnicalIdentifiersInHistory':
            settings.saveTechnicalIdentifiersInHistory,
        'scanTimeoutSeconds': settings.scanTimeoutSeconds,
        'historyLimit': settings.historyLimit,
      },
    );
    _notify();
    try {
      await _repository.saveSettings(settings);
    } on Object catch (error) {
      _errorMessage = 'Could not save settings: ${_cleanError(error)}';
      _notify();
    }
    if (historyTrimmed) {
      await _saveHistoryOrReport('Trim history');
    }
  }

  Future<void> deleteHistoryItem(String id) async {
    _history = _history
        .where((NfcScan scan) => scan.id != id)
        .toList(growable: false);
    _notify();
    await _saveHistoryOrReport('Delete history item');
  }

  Future<void> clearHistory() async {
    _history = const <NfcScan>[];
    _notify();
    try {
      await _repository.clearHistory();
    } on Object catch (error) {
      _errorMessage = 'Could not clear history: ${_cleanError(error)}';
      _notify();
    }
  }

  Future<void> scrubRawUidsFromHistory() async {
    _history = _history
        .map((NfcScan scan) => scan.copyWith(uidHex: null))
        .toList(growable: false);
    _notify();
    await _saveHistoryOrReport('Remove raw identifiers from history');
  }

  Future<void> scrubNdefFromHistory() async {
    _history = _history
        .map(
          (NfcScan scan) =>
              scan.copyWith(ndefRecords: const <NdefRecordInfo>[]),
        )
        .toList(growable: false);
    _notify();
    await _saveHistoryOrReport('Remove NDEF from history');
  }

  Future<void> scrubTechnicalIdentifiersFromHistory() async {
    _history = _history
        .map(
          (NfcScan scan) => scan.copyWith(
            details: TagFactCatalog.privacyScrubbedDetails(scan.details),
          ),
        )
        .toList(growable: false);
    _notify();
    await _saveHistoryOrReport('Remove technical identifiers from history');
  }

  Future<void> _saveHistoryOrReport(String action) async {
    try {
      await _repository.saveHistory(_history);
    } on Object catch (error) {
      _errorMessage = '$action failed: ${_cleanError(error)}';
      _notify();
    }
  }

  Future<void> copyCurrentScanJson() async {
    final NfcScan? scan = _currentScan;
    if (scan == null) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: _prettyJson(_exportEnvelope(<NfcScan>[scan]))),
    );
  }

  Future<void> shareCurrentScanJson() async {
    final NfcScan? scan = _currentScan;
    if (scan == null) {
      return;
    }
    await _exportService.shareTextFile(
      filename: 'tagverity-scan-${_timestampForFilename()}.json',
      content: _prettyJson(_exportEnvelope(<NfcScan>[scan])),
      mimeType: 'application/json',
      subject: 'TagVerity NFC scan',
    );
  }

  Future<void> copyHistoryJson() async {
    await Clipboard.setData(
      ClipboardData(text: _prettyJson(_exportEnvelope(_history))),
    );
  }

  Future<void> shareHistoryJson() async {
    await _exportService.shareTextFile(
      filename: 'tagverity-history-${_timestampForFilename()}.json',
      content: _prettyJson(_exportEnvelope(_history)),
      mimeType: 'application/json',
      subject: 'TagVerity scan history',
    );
  }

  Future<void> copyBatchCsv() async {
    await Clipboard.setData(ClipboardData(text: _batchCsv()));
  }

  Future<void> shareBatchCsv() async {
    await _exportService.shareTextFile(
      filename: 'tagverity-batch-${_timestampForFilename()}.csv',
      content: _batchCsv(),
      mimeType: 'text/csv',
      subject: 'TagVerity batch scan report',
    );
  }

  String _batchCsv() {
    final Set<String> duplicateFingerprints = batchDuplicateFingerprints;
    final StringBuffer buffer = StringBuffer()
      ..writeln(
        'scanned_at,short_fingerprint,identity_stability,technologies,ndef_records,status,warnings,duplicate',
      );
    for (final NfcScan scan in _batchScans) {
      final TagAssessment assessment = TagAssessor.assess(scan);
      buffer.writeln(
        <String>[
          scan.scannedAt.toUtc().toIso8601String(),
          ByteUtils.shortFingerprint(scan.uidFingerprint),
          scan.identityStability.name,
          scan.technologies.join(' | '),
          scan.ndefRecords.length.toString(),
          assessment.status.name,
          scan.warnings.length.toString(),
          scan.hasComparableIdentity
              ? duplicateFingerprints.contains(scan.uidFingerprint)
                    ? 'yes'
                    : 'no'
              : 'unknown',
        ].map(_csv).join(','),
      );
    }
    return buffer.toString();
  }

  Future<void> copyDiagnosticsJson() async {
    final Map<String, Object?> payload = <String, Object?>{
      'schemaVersion': 2,
      'app': AppConstants.appName,
      'appVersion': AppConstants.appVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'supportStatus': _supportStatus.name,
      'isScanning': _isScanning,
      'historyCount': _history.length,
      'batchCount': _batchScans.length,
      'settings': _settings.toJson(),
      'events': _diagnosticEvents
          .map((DiagnosticEvent event) => event.toJson())
          .toList(growable: false),
    };
    await Clipboard.setData(ClipboardData(text: _prettyJson(payload)));
  }

  void clearDiagnostics() {
    _diagnosticEvents = const <DiagnosticEvent>[];
    _notify();
  }

  Map<String, Object?> _exportEnvelope(
    List<NfcScan> scans,
  ) => <String, Object?>{
    'schemaVersion': AppConstants.exportSchemaVersion,
    'app': AppConstants.appName,
    'appVersion': AppConstants.appVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'readOnlyScope': true,
    'scans': scans.map((NfcScan scan) => scan.toJson()).toList(growable: false),
  };

  String _prettyJson(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  String _csv(String value) => '"${value.replaceAll('"', '""')}"';

  String _timestampForFilename() =>
      DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(stopScan());
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _addDiagnostic(
    AppDiagnosticLevel level,
    String code,
    String message, {
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    final Map<String, Object?> sanitizedData = data.map(
      (String key, Object? value) => MapEntry<String, Object?>(
        key,
        value is String ? _redactDiagnosticText(value) : value,
      ),
    );
    final DiagnosticEvent event = DiagnosticEvent(
      timestamp: DateTime.now(),
      level: level,
      code: code,
      message: _redactDiagnosticText(message),
      data: sanitizedData,
    );
    _diagnosticEvents = <DiagnosticEvent>[..._diagnosticEvents, event];
    if (_diagnosticEvents.length > AppConstants.maximumDiagnosticEvents) {
      _diagnosticEvents = _diagnosticEvents
          .skip(_diagnosticEvents.length - AppConstants.maximumDiagnosticEvents)
          .toList(growable: false);
    }
  }

  String _redactDiagnosticText(String value) {
    return value
        .replaceAll(
          RegExp(r'\b(?:[0-9A-Fa-f]{2}:){3,}[0-9A-Fa-f]{2}\b'),
          '[redacted-hex-identifier]',
        )
        .replaceAll(RegExp(r'\b[0-9A-Fa-f]{32,}\b'), '[redacted-long-hex]');
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '')
        .trim();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_readerService.stopScan());
    super.dispose();
  }
}
