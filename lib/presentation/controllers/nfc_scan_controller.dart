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
import '../../domain/models/tag_identity_stability.dart';
import '../../domain/repositories/scan_history_repository.dart';
import '../../domain/services/diagnostics_buffer.dart';
import '../../domain/services/export_service.dart';
import '../../domain/services/history_privacy.dart';
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
  bool _scanStopInProgress = false;
  bool _disposed = false;
  int _scanRequestSeed = 0;
  int? _activeScanRequestId;
  bool _activeScanAddsToBatch = false;
  Future<void> _settingsMutationTail = Future<void>.value();
  int _pendingSettingsMutations = 0;
  Future<void> _historyMutationTail = Future<void>.value();
  int _pendingHistoryMutations = 0;
  bool _batchSessionActive = false;
  bool _batchAutoContinue = false;
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
  bool get settingsBusy => _pendingSettingsMutations > 0;
  bool get historyBusy => _pendingHistoryMutations > 0;
  bool get batchSessionActive => _batchSessionActive;
  bool get batchAutoContinue => _batchAutoContinue;
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
      final List<NfcScan> limitedHistory = history
          .take(AppConstants.defaultHistoryLimit)
          .toList(growable: false);
      final bool requiresPrivacyRewrite =
          history.length != limitedHistory.length ||
          limitedHistory.any(_historyNeedsPrivacyScrub);
      final List<NfcScan> privacySafeHistory = limitedHistory
          .map(_historySafeScan)
          .toList(growable: false);
      _history = privacySafeHistory;
      if (requiresPrivacyRewrite) {
        try {
          await _repository.saveHistory(privacySafeHistory);
          _addDiagnostic(
            AppDiagnosticLevel.info,
            'storage.history.privacy_rewrite',
            'Saved history was rewritten to match current privacy settings.',
            data: <String, Object?>{'historyCount': privacySafeHistory.length},
          );
        } on Object catch (error) {
          _setError(
            'History is hidden safely in this session, but stored sensitive data '
            'could not be rewritten: ${ErrorText.clean(error)}',
            code: 'storage.history.privacy_rewrite.failed',
          );
        }
      }
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
    try {
      _supportStatus = await _readerService.checkAvailability();
    } on Object catch (error) {
      _supportStatus = NfcSupportStatus.unknown;
      _addDiagnostic(
        AppDiagnosticLevel.warning,
        'nfc.availability.check.failed',
        'Could not refresh NFC availability',
        data: <String, Object?>{'error': ErrorText.clean(error)},
      );
    }
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
    if (_disposed || _isScanning || _scanStopInProgress) {
      return;
    }
    if (settingsBusy) {
      if (addToBatch) {
        _batchAutoContinue = false;
      }
      _setError(
        'Wait for the pending settings update before scanning.',
        code: 'nfc.scan.settings_busy',
        level: AppDiagnosticLevel.warning,
      );
      return;
    }
    if (!addToBatch && _batchAutoContinue) {
      _setError(
        'Stop continuous batch scanning before starting a single scan.',
        code: 'nfc.scan.batch_active',
        level: AppDiagnosticLevel.warning,
      );
      return;
    }
    final int requestId = ++_scanRequestSeed;
    _activeScanRequestId = requestId;
    _activeScanAddsToBatch = addToBatch;
    _isScanning = true;
    _errorMessage = null;
    _notify();
    try {
      await refreshAvailability();
    } on Object catch (error) {
      if (!_isActiveScan(requestId)) return;
      _finishScanRequest(requestId);
      if (addToBatch) _batchAutoContinue = false;
      _setError(
        'Could not check NFC availability: ${ErrorText.clean(error)}',
        code: 'nfc.availability.check.failed',
      );
      return;
    }
    if (!_isActiveScan(requestId)) return;
    if (_supportStatus != NfcSupportStatus.enabled) {
      _finishScanRequest(requestId);
      if (addToBatch) _batchAutoContinue = false;
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
        onScan: (NfcScan scan) => _handleScan(requestId, scan, addToBatch),
        onError: (String message) =>
            _handleScanError(requestId, message, addToBatch),
      );
    } on Object catch (error) {
      if (!_isActiveScan(requestId)) return;
      _finishScanRequest(requestId);
      if (addToBatch) _batchAutoContinue = false;
      _setError(ErrorText.clean(error), code: 'nfc.scan.start.failed');
    }
  }

  bool _isActiveScan(int requestId) =>
      !_disposed && _activeScanRequestId == requestId;
  void _finishScanRequest(int requestId) {
    if (_activeScanRequestId != requestId) return;
    _activeScanRequestId = null;
    _activeScanAddsToBatch = false;
    _isScanning = false;
  }

  void _handleScanError(int requestId, String message, bool addToBatch) {
    if (!_isActiveScan(requestId)) return;
    _finishScanRequest(requestId);
    if (addToBatch) _batchAutoContinue = false;
    _errorMessage = message;
    _addDiagnostic(AppDiagnosticLevel.error, 'nfc.scan.failed', message);
    _notify();
  }

  Future<void> startContinuousBatchScan() async {
    if (settingsBusy) {
      _batchAutoContinue = false;
      _setError(
        'Wait for the pending settings update before starting a batch scan.',
        code: 'batch.settings_busy',
        level: AppDiagnosticLevel.warning,
      );
      return;
    }
    if (_isScanning || _scanStopInProgress) {
      _setError(
        'Stop the current scan before starting continuous batch mode.',
        code: 'batch.scan.busy',
        level: AppDiagnosticLevel.warning,
      );
      return;
    }
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
    if (_isScanning && _activeScanAddsToBatch) {
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
    if (settingsBusy) {
      _batchAutoContinue = false;
      _setError(
        'Wait for the pending settings update before starting a batch scan.',
        code: 'batch.settings_busy',
        level: AppDiagnosticLevel.warning,
      );
      return;
    }
    if (_isScanning || _scanStopInProgress) {
      _setError(
        'Wait for the current scan to finish before scanning a batch tag.',
        code: 'batch.scan.busy',
        level: AppDiagnosticLevel.warning,
      );
      return;
    }
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
    if (settingsBusy) {
      _batchAutoContinue = false;
      _setError(
        'Wait for the pending settings update before starting a batch scan.',
        code: 'batch.settings_busy',
        level: AppDiagnosticLevel.warning,
      );
      return;
    }
    if (_batchSessionActive) {
      return;
    }
    if (_isScanning || _scanStopInProgress) {
      _setError(
        'Stop the current scan before starting a batch.',
        code: 'batch.scan.busy',
        level: AppDiagnosticLevel.warning,
      );
      return;
    }
    _batchSessionActive = true;
    _batchAutoContinue = false;
    _batchScans = const <NfcScan>[];
    _batchSummary = BatchSummary.empty;
    _addDiagnostic(
      AppDiagnosticLevel.info,
      'batch.start',
      'Batch session started',
    );
    _notify();
  }

  void finishBatchSession() {
    final bool shouldStopBatchScan = _isScanning && _activeScanAddsToBatch;
    _batchSessionActive = false;
    _batchAutoContinue = false;
    if (shouldStopBatchScan) {
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
    if (_isScanning && _activeScanAddsToBatch) {
      await stopScan();
    }
    _batchSessionActive = false;
    _batchAutoContinue = false;
    _batchScans = const <NfcScan>[];
    _batchSummary = BatchSummary.empty;
    _notify();
  }

  Future<void> stopScan() async {
    if (_scanStopInProgress) {
      return;
    }
    final bool wasScanning = _isScanning;
    _activeScanRequestId = null;
    _activeScanAddsToBatch = false;
    _batchAutoContinue = false;
    _scanStopInProgress = true;
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
      _isScanning = false;
      _scanStopInProgress = false;
      _notify();
    }
  }

  Future<void> _handleScan(int requestId, NfcScan scan, bool addToBatch) async {
    if (!_isActiveScan(requestId)) {
      return;
    }
    _finishScanRequest(requestId);
    _currentScan = scan;
    _errorMessage = null;
    if (addToBatch && !batchAtCapacity) {
      _batchScans = <NfcScan>[..._batchScans, scan].toList(growable: false);
      _batchSummary = BatchSummary.fromScans(_batchScans);
    }
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
      await _enqueueHistoryMutation(() async {
        final NfcScan persisted = _historySafeScan(scan);
        final List<NfcScan> nextHistory = <NfcScan>[
          persisted,
          ..._history.where((NfcScan item) => item.id != persisted.id),
        ].take(AppConstants.defaultHistoryLimit).toList(growable: false);
        await _repository.saveHistory(nextHistory);
        // Settings can change while the disk write is in flight. Re-apply the
        // latest privacy policy before exposing the updated list in memory.
        _history = nextHistory.map(_historySafeScan).toList(growable: false);
        _notify();
      });
    } on Object catch (error) {
      if (addToBatch) {
        _batchAutoContinue = false;
      }
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
    final bool retainComparableIdentity =
        _settings.saveTechnicalIdentifiersInHistory;
    return scan.copyWith(
      id: scan.id,
      uidHex: _settings.saveRawUidInHistory ? scan.uidHex : null,
      uidFingerprint: retainComparableIdentity
          ? scan.uidFingerprint
          : _historySessionFingerprint(scan),
      identityStability: retainComparableIdentity
          ? scan.identityStability
          : TagIdentityStability.sessionOnly,
      details: retainComparableIdentity
          ? scan.details
          : TagFactCatalog.privacyScrubbedDetails(scan.details),
      ndefRecords: _settings.saveNdefInHistory
          ? scan.ndefRecords
          : const <NdefRecordInfo>[],
    );
  }

  NfcScan _fullyPrivacyScrubbedHistoryScan(NfcScan scan) {
    return scan.copyWith(
      id: scan.id,
      uidHex: null,
      uidFingerprint: _historySessionFingerprint(scan),
      identityStability: TagIdentityStability.sessionOnly,
      details: TagFactCatalog.privacyScrubbedDetails(scan.details),
      ndefRecords: const <NdefRecordInfo>[],
    );
  }

  String _historySessionFingerprint(NfcScan scan) =>
      HistoryPrivacy.sessionFingerprint(scan);

  bool _historyNeedsPrivacyScrub(NfcScan scan) {
    final bool identityNeedsScrub =
        !_settings.saveTechnicalIdentifiersInHistory &&
        (scan.identityStability != TagIdentityStability.sessionOnly ||
            scan.uidFingerprint != _historySessionFingerprint(scan));
    return (!_settings.saveRawUidInHistory && scan.uidHex != null) ||
        (!_settings.saveNdefInHistory && scan.ndefRecords.isNotEmpty) ||
        identityNeedsScrub ||
        (!_settings.saveTechnicalIdentifiersInHistory &&
            scan.details.keys.any(TagFactCatalog.isLinkable));
  }

  Future<bool> updateSettings(
    ScanSettings Function(ScanSettings current) transform,
  ) {
    final Completer<bool> completer = Completer<bool>();
    _pendingSettingsMutations++;
    _notify();
    _settingsMutationTail = _settingsMutationTail.then((_) async {
      try {
        if (_disposed) {
          completer.complete(false);
          return;
        }
        final bool result = await _applySettings(transform(_settings));
        completer.complete(result);
      } on Object catch (error) {
        _setError(
          'Could not apply settings: ${ErrorText.clean(error)}',
          code: 'settings.update.failed',
        );
        completer.complete(false);
      } finally {
        _pendingSettingsMutations--;
        _notify();
      }
    });
    return completer.future;
  }

  Future<bool> _applySettings(ScanSettings nextSettings) async {
    final ScanSettings previous = _settings;
    final bool disablingSensitiveRetention =
        (previous.saveRawUidInHistory && !nextSettings.saveRawUidInHistory) ||
        (previous.saveNdefInHistory && !nextSettings.saveNdefInHistory) ||
        (previous.saveTechnicalIdentifiersInHistory &&
            !nextSettings.saveTechnicalIdentifiersInHistory);
    try {
      // Commit the privacy setting first. Future scans immediately follow the
      // new retention policy even if rewriting older history later fails.
      await _repository.saveSettings(nextSettings);
      _settings = nextSettings;
    } on Object catch (error) {
      _setError(
        'Could not save settings: ${ErrorText.clean(error)}',
        code: 'storage.settings.save.failed',
      );
      return false;
    }
    if (disablingSensitiveRetention) {
      // Never re-expose sensitive data in this running session. A queued disk
      // rewrite will run after any scan/history write already in flight.
      _history = _history.map(_historySafeScan).toList(growable: false);
      _notify();
      try {
        await _enqueueHistoryMutation(() async {
          final List<NfcScan> scrubbedHistory = _history
              .map(_historySafeScan)
              .toList(growable: false);
          _history = scrubbedHistory;
          _notify();
          await _repository.saveHistory(scrubbedHistory);
        });
      } on Object catch (error) {
        _setError(
          'Setting updated, but saved history could not be scrubbed on disk: '
          '${ErrorText.clean(error)}',
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

  Future<bool> deleteHistoryItem(String id) {
    return _mutateHistoryPersisted(
      'Delete history item',
      (List<NfcScan> current) => current
          .where((NfcScan scan) => scan.id != id)
          .toList(growable: false),
    );
  }

  Future<bool> clearHistory() async {
    try {
      await _enqueueHistoryMutation(() async {
        await _repository.clearHistory();
        _history = const <NfcScan>[];
        _errorMessage = null;
        _notify();
      });
      return true;
    } on Object catch (error) {
      _setError(
        'Could not clear history: ${ErrorText.clean(error)}',
        code: 'storage.history.clear.failed',
      );
      return false;
    }
  }

  Future<bool> scrubSensitiveHistory() {
    return _mutateHistoryPersisted(
      'Remove sensitive data from history',
      (List<NfcScan> current) =>
          current.map(_fullyPrivacyScrubbedHistoryScan).toList(growable: false),
    );
  }

  Future<bool> _mutateHistoryPersisted(
    String action,
    List<NfcScan> Function(List<NfcScan> current) transform,
  ) async {
    try {
      await _enqueueHistoryMutation(() async {
        final List<NfcScan> nextHistory = transform(_history);
        await _repository.saveHistory(nextHistory);
        _history = nextHistory;
        _errorMessage = null;
        _notify();
      });
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

  Future<void> _enqueueHistoryMutation(Future<void> Function() action) {
    final Completer<void> completer = Completer<void>();
    _pendingHistoryMutations++;
    _notify();
    _historyMutationTail = _historyMutationTail.then((_) async {
      try {
        await action();
        completer.complete();
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _pendingHistoryMutations--;
        _notify();
      }
    });
    return completer.future;
  }

  Future<bool> copyCurrentScanJson() async {
    final NfcScan? scan = _currentScan;
    if (scan == null) return false;
    return _copyText(
      ReportEncoder.prettyJson(ReportEncoder.exportEnvelope(<NfcScan>[scan])),
      label: 'scan JSON',
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

  Future<bool> copyHistoryJson() {
    return _copyText(
      ReportEncoder.prettyJson(ReportEncoder.exportEnvelope(_history)),
      label: 'history JSON',
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

  Future<bool> copyBatchCsv() {
    return _copyText(
      ReportEncoder.batchCsv(_batchScans, summary: _batchSummary),
      label: 'batch CSV',
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

  Future<bool> copyDiagnosticsJson() async {
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
    return _copyText(
      ReportEncoder.prettyJson(payload),
      label: 'diagnostics JSON',
    );
  }

  Future<bool> _copyText(String text, {required String label}) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } on Object catch (error) {
      _setError(
        'Could not copy $label: ${ErrorText.clean(error)}',
        code: 'export.copy.failed',
        data: <String, Object?>{'label': label},
      );
      return false;
    }
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
    _activeScanRequestId = null;
    _activeScanAddsToBatch = false;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_readerService.stopScan().catchError((Object _) {}));
    super.dispose();
  }
}
