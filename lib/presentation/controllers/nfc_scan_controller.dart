import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/error_text.dart';
import '../../data/nfc/nfc_reader_service.dart';
import '../../domain/models/batch_summary.dart';
import '../../domain/models/diagnostic_event.dart';
import '../../domain/models/ndef_record_info.dart';
import '../../domain/models/nfc_scan.dart';
import '../../domain/models/nfc_support_status.dart';
import '../../domain/models/scan_settings.dart';
import '../../domain/models/tag_assessment.dart';
import '../../domain/models/tag_fact_catalog.dart';
import '../../domain/repositories/scan_history_repository.dart';
import '../../domain/services/diagnostics_buffer.dart';
import '../../domain/services/export_service.dart';
import '../../domain/services/report_encoder.dart';
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
  final DiagnosticsBuffer _diagnostics = DiagnosticsBuffer();
  NfcSupportStatus _supportStatus = NfcSupportStatus.unknown;
  ScanSettings _settings = const ScanSettings();
  List<NfcScan> _history = const <NfcScan>[];
  List<NfcScan> _batchScans = const <NfcScan>[];
  BatchSummary _batchSummary = BatchSummary.empty;
  NfcScan? _currentScan;
  String? _errorMessage;
  bool _initialized = false;
  bool _isScanning = false;
  bool _disposed = false;
  bool _batchSessionActive = false;
  bool _batchAutoContinue = false;
  bool _captureNextScanInBatch = false;
  DateTime? _batchStartedAt;
  NfcSupportStatus get supportStatus => _supportStatus;
  ScanSettings get settings => _settings;
  List<NfcScan> get history => List<NfcScan>.unmodifiable(_history);
  List<DiagnosticEvent> get diagnosticEvents => _diagnostics.events;
  List<NfcScan> get batchScans => List<NfcScan>.unmodifiable(_batchScans);
  BatchSummary get batchSummary => _batchSummary;
  NfcScan? get currentScan => _currentScan;
  String? get errorMessage => _errorMessage;
  bool get initialized => _initialized;
  bool get isScanning => _isScanning;
  bool get batchSessionActive => _batchSessionActive;
  bool get batchAutoContinue => _batchAutoContinue;
  DateTime? get batchStartedAt => _batchStartedAt;
  TagAssessment? get currentAssessment =>
      _currentScan == null ? null : TagAssessor.assess(_currentScan!);
  bool get batchAtCapacity =>
      _batchScans.length >= AppConstants.maximumBatchScans;
  Future<void> initialize() async {
    _addDiagnostic(
      AppDiagnosticLevel.info,
      'app.initialize.start',
      'Initializing TagVerity',
    );
    try {
      _settings = await _repository.loadSettings();
    } on Object catch (error) {
      _setError(
        'Could not load saved settings: ${ErrorText.clean(error)}',
        code: 'storage.settings.load.failed',
      );
    }
    try {
      final List<NfcScan> history = await _repository.loadHistory();
      _history = history
          .take(AppConstants.defaultHistoryLimit)
          .toList(growable: false);
    } on Object catch (error) {
      _setError(
        'Could not load saved history: ${ErrorText.clean(error)}',
        code: 'storage.history.load.failed',
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
      if (addToBatch) {
        _batchAutoContinue = false;
      }
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
        'timeoutSeconds': AppConstants.defaultScanTimeoutSeconds,
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
          _batchAutoContinue = false;
          _captureNextScanInBatch = false;
          _isScanning = false;
          _errorMessage = message;
          _addDiagnostic(AppDiagnosticLevel.error, 'nfc.scan.failed', message);
          _notify();
        },
      );
    } on Object catch (error) {
      _batchAutoContinue = false;
      _captureNextScanInBatch = false;
      _isScanning = false;
      _setError(ErrorText.clean(error), code: 'nfc.scan.start.failed');
    }
  }

  Future<void> startContinuousBatchScan() async {
    if (batchAtCapacity) {
      _reportBatchCapacity();
      return;
    }
    if (!_batchSessionActive) {
      startBatchSession();
    }
    _batchAutoContinue = true;
    _addDiagnostic(
      AppDiagnosticLevel.info,
      'batch.continuous.start',
      'Continuous batch scanning started',
    );
    _notify();
    await startScan(addToBatch: true);
  }

  Future<void> stopContinuousBatchScan() async {
    final bool wasActive = _batchAutoContinue;
    _batchAutoContinue = false;
    if (_isScanning && _captureNextScanInBatch) {
      await stopScan();
    } else {
      _notify();
    }
    if (wasActive) {
      _addDiagnostic(
        AppDiagnosticLevel.info,
        'batch.continuous.stop',
        'Continuous batch scanning stopped',
      );
      _notify();
    }
  }

  Future<void> startBatchScan() async {
    if (batchAtCapacity) {
      _reportBatchCapacity();
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
    _batchAutoContinue = false;
    _batchScans = const <NfcScan>[];
    _batchSummary = BatchSummary.empty;
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
    _batchAutoContinue = false;
    _captureNextScanInBatch = false;
    if (_isScanning) {
      unawaited(stopScan());
    }
    _addDiagnostic(
      AppDiagnosticLevel.info,
      'batch.finish',
      'Batch session finished',
      data: <String, Object?>{
        'scanCount': _batchSummary.total,
        'distinctComparableIds': _batchSummary.distinctComparableIds,
        'repeatedIds': _batchSummary.repeatedIdCount,
      },
    );
    _notify();
  }

  Future<void> clearBatchSession() async {
    if (_isScanning && _captureNextScanInBatch) {
      await stopScan();
    }
    _batchSessionActive = false;
    _batchAutoContinue = false;
    _captureNextScanInBatch = false;
    _batchScans = const <NfcScan>[];
    _batchSummary = BatchSummary.empty;
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
      _setError(
        'Could not stop NFC scanning: ${ErrorText.clean(error)}',
        code: 'nfc.scan.stop.failed',
      );
    } finally {
      _batchAutoContinue = false;
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
      _batchSummary = BatchSummary.fromScans(_batchScans);
    }
    final NfcScan persisted = _historySafeScan(scan);
    final List<NfcScan> nextHistory = <NfcScan>[
      persisted,
      ..._history.where((NfcScan item) => item.id != persisted.id),
    ].take(AppConstants.defaultHistoryLimit).toList(growable: false);
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
      await _repository.saveHistory(nextHistory);
      _history = nextHistory;
      _notify();
    } on Object catch (error) {
      _setError(
        'Could not save scan history: ${ErrorText.clean(error)}',
        code: 'storage.history.save.failed',
      );
    }
    if (_batchAutoContinue &&
        _batchSessionActive &&
        !batchAtCapacity &&
        !_disposed) {
      // NfcManagerReaderService closes the native reader session before it
      // delivers this callback, so no artificial rearm delay is necessary.
      unawaited(startScan(addToBatch: true));
    } else if (batchAtCapacity) {
      _batchAutoContinue = false;
      _notify();
    }
  }

  NfcScan _historySafeScan(NfcScan scan) {
    return scan.copyWith(
      uidHex: _settings.saveRawUidInHistory ? scan.uidHex : null,
      details: _settings.saveTechnicalIdentifiersInHistory
          ? scan.details
          : TagFactCatalog.privacyScrubbedDetails(scan.details),
      ndefRecords: _settings.saveNdefInHistory
          ? scan.ndefRecords
          : const <NdefRecordInfo>[],
    );
  }

  Future<bool> updateSettings(ScanSettings nextSettings) async {
    final ScanSettings previous = _settings;
    final bool disablingSensitiveRetention =
        (previous.saveRawUidInHistory && !nextSettings.saveRawUidInHistory) ||
        (previous.saveNdefInHistory && !nextSettings.saveNdefInHistory) ||
        (previous.saveTechnicalIdentifiersInHistory &&
            !nextSettings.saveTechnicalIdentifiersInHistory);
    List<NfcScan>? scrubbedHistory;
    if (disablingSensitiveRetention) {
      scrubbedHistory = _history
          .map((NfcScan scan) {
            return scan.copyWith(
              uidHex: nextSettings.saveRawUidInHistory ? scan.uidHex : null,
              ndefRecords: nextSettings.saveNdefInHistory
                  ? scan.ndefRecords
                  : const <NdefRecordInfo>[],
              details: nextSettings.saveTechnicalIdentifiersInHistory
                  ? scan.details
                  : TagFactCatalog.privacyScrubbedDetails(scan.details),
            );
          })
          .toList(growable: false);
    }
    try {
      // Commit the privacy setting first. If historical cleanup later fails,
      // future scans still stop retaining the disabled sensitive field.
      await _repository.saveSettings(nextSettings);
      _settings = nextSettings;
    } on Object catch (error) {
      _setError(
        'Could not save settings: ${ErrorText.clean(error)}',
        code: 'storage.settings.save.failed',
      );
      return false;
    }
    if (scrubbedHistory != null) {
      try {
        await _repository.saveHistory(scrubbedHistory);
        _history = scrubbedHistory;
      } on Object catch (error) {
        _setError(
          'Setting updated, but saved history could not be scrubbed: ${ErrorText.clean(error)}',
          code: 'storage.history.scrub.after_setting.failed',
        );
        return false;
      }
    }
    _errorMessage = null;
    _addDiagnostic(
      AppDiagnosticLevel.info,
      'settings.updated',
      'Settings updated',
      data: <String, Object?>{
        'readNdef': nextSettings.readNdef,
        'saveRawUidInHistory': nextSettings.saveRawUidInHistory,
        'saveNdefInHistory': nextSettings.saveNdefInHistory,
        'saveTechnicalIdentifiersInHistory':
            nextSettings.saveTechnicalIdentifiersInHistory,
      },
    );
    _notify();
    return true;
  }

  Future<bool> deleteHistoryItem(String id) async {
    final List<NfcScan> nextHistory = _history
        .where((NfcScan scan) => scan.id != id)
        .toList(growable: false);
    return _replaceHistoryPersisted(nextHistory, 'Delete history item');
  }

  Future<bool> clearHistory() async {
    try {
      await _repository.clearHistory();
      _history = const <NfcScan>[];
      _errorMessage = null;
      _notify();
      return true;
    } on Object catch (error) {
      _setError(
        'Could not clear history: ${ErrorText.clean(error)}',
        code: 'storage.history.clear.failed',
      );
      return false;
    }
  }

  Future<bool> scrubSensitiveHistory() async {
    final List<NfcScan> nextHistory = _history
        .map(
          (NfcScan scan) => scan.copyWith(
            uidHex: null,
            ndefRecords: const <NdefRecordInfo>[],
            details: TagFactCatalog.privacyScrubbedDetails(scan.details),
          ),
        )
        .toList(growable: false);
    return _replaceHistoryPersisted(
      nextHistory,
      'Remove sensitive data from history',
    );
  }

  Future<bool> _replaceHistoryPersisted(
    List<NfcScan> nextHistory,
    String action,
  ) async {
    try {
      await _repository.saveHistory(nextHistory);
      _history = nextHistory;
      _errorMessage = null;
      _notify();
      return true;
    } on Object catch (error) {
      _setError(
        '$action failed: ${ErrorText.clean(error)}',
        code: 'storage.history.mutation.failed',
        data: <String, Object?>{'action': action},
      );
      return false;
    }
  }

  Future<void> copyCurrentScanJson() async {
    final NfcScan? scan = _currentScan;
    if (scan == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: ReportEncoder.prettyJson(
          ReportEncoder.exportEnvelope(<NfcScan>[scan]),
        ),
      ),
    );
  }

  Future<void> shareCurrentScanJson() async {
    final NfcScan? scan = _currentScan;
    if (scan == null) return;
    await _shareTextFile(
      filename: 'tagverity-scan-${ReportEncoder.timestampForFilename()}.json',
      content: ReportEncoder.prettyJson(
        ReportEncoder.exportEnvelope(<NfcScan>[scan]),
      ),
      mimeType: 'application/json',
      subject: 'TagVerity NFC scan',
    );
  }

  Future<void> copyHistoryJson() async {
    await Clipboard.setData(
      ClipboardData(
        text: ReportEncoder.prettyJson(ReportEncoder.exportEnvelope(_history)),
      ),
    );
  }

  Future<void> shareHistoryJson() async {
    await _shareTextFile(
      filename:
          'tagverity-history-${ReportEncoder.timestampForFilename()}.json',
      content: ReportEncoder.prettyJson(ReportEncoder.exportEnvelope(_history)),
      mimeType: 'application/json',
      subject: 'TagVerity scan history',
    );
  }

  Future<void> copyBatchCsv() async {
    await Clipboard.setData(
      ClipboardData(
        text: ReportEncoder.batchCsv(_batchScans, summary: _batchSummary),
      ),
    );
  }

  Future<void> shareBatchCsv() async {
    await _shareTextFile(
      filename: 'tagverity-batch-${ReportEncoder.timestampForFilename()}.csv',
      content: ReportEncoder.batchCsv(_batchScans, summary: _batchSummary),
      mimeType: 'text/csv',
      subject: 'TagVerity batch scan report',
    );
  }

  Future<void> _shareTextFile({
    required String filename,
    required String content,
    required String mimeType,
    required String subject,
  }) async {
    try {
      await _exportService.shareTextFile(
        filename: filename,
        content: content,
        mimeType: mimeType,
        subject: subject,
      );
    } on Object catch (error) {
      _setError(
        'Could not share report: ${ErrorText.clean(error)}',
        code: 'export.share.failed',
        data: <String, Object?>{'subject': subject},
      );
    }
  }

  Future<void> copyDiagnosticsJson() async {
    final Map<String, Object?> payload = <String, Object?>{
      'schemaVersion': AppConstants.diagnosticsSchemaVersion,
      'app': AppConstants.appName,
      'appVersion': AppConstants.appVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'supportStatus': _supportStatus.name,
      'isScanning': _isScanning,
      'historyCount': _history.length,
      'batchCount': _batchScans.length,
      'settings': _settings.toJson(),
      'events': _diagnostics.events
          .map((DiagnosticEvent event) => event.toJson())
          .toList(growable: false),
    };
    await Clipboard.setData(
      ClipboardData(text: ReportEncoder.prettyJson(payload)),
    );
  }

  void clearDiagnostics() {
    _diagnostics.clear();
    _notify();
  }

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  void _reportBatchCapacity() {
    _setError(
      'This batch reached the ${AppConstants.maximumBatchScans}-scan limit. '
      'Finish or clear it before scanning more tags.',
      code: 'batch.capacity.reached',
      level: AppDiagnosticLevel.warning,
      data: <String, Object?>{'limit': AppConstants.maximumBatchScans},
    );
  }

  void _setError(
    String message, {
    required String code,
    AppDiagnosticLevel level = AppDiagnosticLevel.error,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    _errorMessage = message;
    _addDiagnostic(level, code, message, data: data);
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshAvailability());
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _batchAutoContinue = false;
      if (_isScanning) {
        unawaited(stopScan());
      }
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
    _diagnostics.add(level, code, message, data: data);
  }

  @override
  void dispose() {
    _batchAutoContinue = false;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_readerService.stopScan());
    super.dispose();
  }
}
