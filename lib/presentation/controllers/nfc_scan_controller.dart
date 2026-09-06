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
  int _availabilityRequestSeed = 0;
  int? _activeScanRequestId;
  bool _activeScanAddsToBatch = false;
  Future<void> _settingsMutationTail = Future<void>.value();
  int _pendingSettingsMutations = 0;
  Future<void> _historyMutationTail = Future<void>.value();
  int _pendingHistoryMutations = 0;
  bool _batchSessionActive = false;
  bool _batchAutoContinue = false;
  bool _historyLoadDeferredForSettings = false;
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
  bool get privacySettingsRecoveryRequired => _historyLoadDeferredForSettings;
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
    bool settingsLoaded = true;
    try {
      _settings = await _repository.loadSettings();
    } on Object catch (error) {
      settingsLoaded = false;
      _historyLoadDeferredForSettings = true;
      _setError(
        'Could not load saved settings: ${ErrorText.clean(error)}',
        code: 'storage.settings.load.failed',
      );
      _addDiagnostic(
        AppDiagnosticLevel.warning,
        'storage.history.load.deferred',
        'Saved history was not loaded because privacy settings are unavailable.',
      );
    }
    if (settingsLoaded) {
      await _loadHistoryForCurrentSettings();
    } else {
      // The privacy policy is unknown. Keep history hidden and do not touch
      // the persisted copy until settings are successfully saved again.
      _history = const <NfcScan>[];
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

  Future<({bool loaded, bool complete})>
  _loadHistoryForCurrentSettings() async {
    try {
      final List<NfcScan> history = await _repository.loadHistory();
      final List<NfcScan> limitedHistory = history
          .take(AppConstants.defaultHistoryLimit)
          .toList(growable: false);
      final bool requiresPrivacyRewrite =
          history.length != limitedHistory.length ||
          limitedHistory.any(_historyNeedsPrivacyScrub);
      final List<NfcScan> privacySafeHistory = <NfcScan>[
        for (final MapEntry<int, NfcScan> entry
            in limitedHistory.asMap().entries)
          _historySafeScan(entry.value, historyOrdinal: entry.key),
      ];
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
          return (loaded: true, complete: false);
        }
      }
      return (loaded: true, complete: true);
    } on Object catch (error) {
      _setError(
        'Could not load saved history: ${ErrorText.clean(error)}',
        code: 'storage.history.load.failed',
      );
      return (loaded: false, complete: false);
    }
  }

  Future<NfcSupportStatus> refreshAvailability() async {
    final int requestId = ++_availabilityRequestSeed;
    final NfcSupportStatus previous = _supportStatus;
    late NfcSupportStatus status;
    String? failure;
    try {
      status = await _readerService.checkAvailability();
    } on Object catch (error) {
      status = NfcSupportStatus.unknown;
      failure = ErrorText.clean(error);
    }
    if (_disposed || requestId != _availabilityRequestSeed) {
      return _supportStatus;
    }
    if (failure != null) {
      _addDiagnostic(
        AppDiagnosticLevel.warning,
        'nfc.availability.check.failed',
        'Could not refresh NFC availability',
        data: <String, Object?>{'error': failure},
      );
    }
    _supportStatus = status;
    if (_supportStatus != previous) {
      _addDiagnostic(
        AppDiagnosticLevel.info,
        'nfc.availability.changed',
        'NFC availability changed',
        data: <String, Object?>{'status': _supportStatus.name},
      );
    }
    _notify();
    return status;
  }

  bool _requireKnownPrivacySettings(String code) {
    if (!_historyLoadDeferredForSettings) {
      return true;
    }
    _batchAutoContinue = false;
    _setError(
      'Saved privacy settings could not be loaded. Open Settings, choose the '
      'privacy options you want, then apply them to saved history before '
      'scanning.',
      code: code,
      level: AppDiagnosticLevel.warning,
    );
    return false;
  }

  Future<void> startScan({bool addToBatch = false}) async {
    if (_disposed || _isScanning || _scanStopInProgress) {
      return;
    }
    if (!_requireKnownPrivacySettings(
      'nfc.scan.privacy_settings_unavailable',
    )) {
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
    late NfcSupportStatus supportStatus;
    _notify();
    try {
      supportStatus = await refreshAvailability();
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
    if (supportStatus != NfcSupportStatus.enabled) {
      _finishScanRequest(requestId);
      if (addToBatch) _batchAutoContinue = false;
      _errorMessage = switch (supportStatus) {
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
    _setError(message, code: 'nfc.scan.failed');
  }

  Future<void> startContinuousBatchScan() async {
    if (!_requireKnownPrivacySettings('batch.privacy_settings_unavailable')) {
      return;
    }
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
    if (!_requireKnownPrivacySettings('batch.privacy_settings_unavailable')) {
      return;
    }
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
    if (!_requireKnownPrivacySettings('batch.privacy_settings_unavailable')) {
      return;
    }
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

  NfcScan _historySafeScan(NfcScan scan, {int? historyOrdinal}) {
    final String safeEventId = HistoryPrivacy.safeEventId(
      scan,
      ordinal: historyOrdinal,
    );
    final identity = _historyIdentity(scan, eventId: safeEventId);
    return scan.copyWith(
      id: safeEventId,
      uidHex: identity.uidHex,
      uidFingerprint: identity.fingerprint,
      identityStability: identity.stability,
      details: TagFactCatalog.historyRetainedDetails(
        scan.details,
        includeLinkable: _settings.saveTechnicalIdentifiersInHistory,
      ),
      ndefRecords: _settings.saveNdefInHistory
          ? scan.ndefRecords
          : const <NdefRecordInfo>[],
      warnings: HistoryPrivacy.safeWarnings(scan.warnings),
    );
  }

  ({String? uidHex, String fingerprint, TagIdentityStability stability})
  _historyIdentity(NfcScan scan, {required String eventId}) {
    final String? retainedUid = _settings.saveRawUidInHistory
        ? scan.uidHex
        : null;
    final String? uidFingerprint =
        HistoryPrivacy.comparableFingerprintFromUidHex(retainedUid);
    if (uidFingerprint != null) {
      return (
        uidHex: retainedUid,
        fingerprint: uidFingerprint,
        stability: TagIdentityStability.stable,
      );
    }
    if (_settings.saveTechnicalIdentifiersInHistory) {
      return (
        uidHex: retainedUid,
        fingerprint: scan.uidFingerprint,
        stability: scan.identityStability,
      );
    }
    return (
      uidHex: retainedUid,
      fingerprint: _historySessionFingerprint(scan, eventId: eventId),
      stability: TagIdentityStability.sessionOnly,
    );
  }

  NfcScan _fullyPrivacyScrubbedHistoryScan(NfcScan scan) {
    final String safeEventId = HistoryPrivacy.safeEventId(scan);
    return scan.copyWith(
      id: safeEventId,
      uidHex: null,
      uidFingerprint: _historySessionFingerprint(scan, eventId: safeEventId),
      identityStability: TagIdentityStability.sessionOnly,
      details: TagFactCatalog.privacyScrubbedDetails(scan.details),
      ndefRecords: const <NdefRecordInfo>[],
      warnings: HistoryPrivacy.safeWarnings(scan.warnings),
    );
  }

  String _historySessionFingerprint(NfcScan scan, {String? eventId}) =>
      HistoryPrivacy.sessionFingerprint(scan, eventId: eventId);

  bool _historyNeedsPrivacyScrub(NfcScan scan) {
    final String safeEventId = HistoryPrivacy.safeEventId(scan);
    final identity = _historyIdentity(scan, eventId: safeEventId);
    return HistoryPrivacy.eventIdNeedsScrub(scan.id) ||
        scan.uidHex != identity.uidHex ||
        scan.uidFingerprint != identity.fingerprint ||
        scan.identityStability != identity.stability ||
        (!_settings.saveNdefInHistory && scan.ndefRecords.isNotEmpty) ||
        scan.details.keys.any(
          (String key) => !TagFactCatalog.isHistoryRetainable(
            key,
            includeLinkable: _settings.saveTechnicalIdentifiersInHistory,
          ),
        ) ||
        HistoryPrivacy.warningsNeedScrub(scan.warnings);
  }

  Future<bool> updateSettings(
    ScanSettings Function(ScanSettings current) transform,
  ) {
    return _enqueueSettingsMutation(
      () => _applySettings(transform(_settings)),
      failureMessage: 'Could not apply settings',
      failureCode: 'settings.update.failed',
    );
  }

  Future<bool> _enqueueSettingsMutation(
    Future<bool> Function() action, {
    required String failureMessage,
    required String failureCode,
  }) {
    final Completer<bool> completer = Completer<bool>();
    _pendingSettingsMutations++;
    _notify();
    _settingsMutationTail = _settingsMutationTail.then((_) async {
      try {
        if (_disposed) {
          completer.complete(false);
          return;
        }
        completer.complete(await action());
      } on Object catch (error) {
        _setError(
          '$failureMessage: ${ErrorText.clean(error)}',
          code: failureCode,
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
    if (!_historyLoadDeferredForSettings && disablingSensitiveRetention) {
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
    if (_historyLoadDeferredForSettings) {
      _setError(
        'Privacy settings updated. Saved history is still hidden; apply the '
        'current privacy settings to saved history before scanning.',
        code: 'storage.history.recovery_required',
        level: AppDiagnosticLevel.warning,
      );
    } else {
      _errorMessage = null;
    }
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

  Future<bool> applyCurrentPrivacySettingsToSavedHistory() {
    if (_disposed) {
      return Future<bool>.value(false);
    }
    if (!_historyLoadDeferredForSettings) {
      return Future<bool>.value(true);
    }
    if (historyBusy) {
      _setError(
        'Wait for the pending history update before recovering saved history.',
        code: 'storage.history.recovery.busy',
        level: AppDiagnosticLevel.warning,
      );
      return Future<bool>.value(false);
    }
    return _enqueueSettingsMutation(
      () async {
        if (!_historyLoadDeferredForSettings) {
          return true;
        }
        if (historyBusy) {
          _setError(
            'Wait for the pending history update before recovering saved history.',
            code: 'storage.history.recovery.busy',
            level: AppDiagnosticLevel.warning,
          );
          return false;
        }
        try {
          // Establish the complete current policy first. This also repairs a
          // corrupt/unreadable settings value when the user explicitly chooses
          // to recover saved history.
          await _repository.saveSettings(_settings);
        } on Object catch (error) {
          _setError(
            'Could not save the current privacy settings: '
            '${ErrorText.clean(error)}',
            code: 'storage.history.recovery.settings_save.failed',
          );
          return false;
        }
        final ({bool loaded, bool complete}) recovery =
            await _loadHistoryForCurrentSettings();
        if (!recovery.loaded) {
          return false;
        }
        _historyLoadDeferredForSettings = false;
        if (recovery.complete) {
          _errorMessage = null;
          _addDiagnostic(
            AppDiagnosticLevel.info,
            'storage.history.load.recovered',
            'Saved history recovered using the current privacy settings.',
            data: <String, Object?>{'historyCount': _history.length},
          );
        }
        _notify();
        return recovery.complete;
      },
      failureMessage: 'Could not recover saved history',
      failureCode: 'storage.history.recovery.failed',
    );
  }

  Future<bool> deleteSavedHistoryDuringPrivacyRecovery() async {
    if (_disposed || !_historyLoadDeferredForSettings) {
      return false;
    }
    if (settingsBusy || historyBusy) {
      _setError(
        'Wait for the pending local update before deleting saved history.',
        code: 'storage.history.recovery.delete.busy',
        level: AppDiagnosticLevel.warning,
      );
      return false;
    }
    try {
      await _enqueueHistoryMutation(() async {
        await _repository.clearHistory();
        _history = const <NfcScan>[];
      });
      _setError(
        'Saved history was deleted. Apply the current privacy settings '
        'before scanning.',
        code: 'storage.history.recovery.deleted',
        level: AppDiagnosticLevel.warning,
      );
      return true;
    } on Object catch (error) {
      _setError(
        'Could not delete saved history: ${ErrorText.clean(error)}',
        code: 'storage.history.recovery.delete.failed',
      );
      return false;
    }
  }

  bool _requireHistoryRecovered(String action) {
    if (!_historyLoadDeferredForSettings) {
      return true;
    }
    _setError(
      'Saved history is hidden until the current privacy settings '
      'are applied. Recover history before $action.',
      code: 'storage.history.recovery_required',
      level: AppDiagnosticLevel.warning,
      data: <String, Object?>{'action': action},
    );
    return false;
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
    if (!_requireHistoryRecovered('clearing it')) {
      return false;
    }
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
    if (!_requireHistoryRecovered(action.toLowerCase())) {
      return false;
    }
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
    final String? content = _prepareExport(
      'scan JSON',
      () => ReportEncoder.prettyJson(
        ReportEncoder.exportEnvelope(<NfcScan>[scan]),
      ),
    );
    if (content == null) return false;
    return _copyText(content, label: 'scan JSON');
  }

  Future<void> shareCurrentScanJson() async {
    final NfcScan? scan = _currentScan;
    if (scan == null) return;
    final String? content = _prepareExport(
      'scan JSON',
      () => ReportEncoder.prettyJson(
        ReportEncoder.exportEnvelope(<NfcScan>[scan]),
      ),
    );
    if (content == null) return;
    await _shareTextFile(
      filename: 'tagverity-scan-${ReportEncoder.timestampForFilename()}.json',
      content: content,
      mimeType: 'application/json',
      subject: 'TagVerity NFC scan',
    );
  }

  Future<bool> copyHistoryJson() async {
    final String? content = _prepareExport(
      'history JSON',
      () => ReportEncoder.prettyJson(ReportEncoder.exportEnvelope(_history)),
    );
    if (content == null) return false;
    return _copyText(content, label: 'history JSON');
  }

  Future<void> shareHistoryJson() async {
    final String? content = _prepareExport(
      'history JSON',
      () => ReportEncoder.prettyJson(ReportEncoder.exportEnvelope(_history)),
    );
    if (content == null) return;
    await _shareTextFile(
      filename:
          'tagverity-history-${ReportEncoder.timestampForFilename()}.json',
      content: content,
      mimeType: 'application/json',
      subject: 'TagVerity scan history',
    );
  }

  Future<bool> copyBatchCsv() async {
    final String? content = _prepareExport(
      'batch CSV',
      () => ReportEncoder.batchCsv(_batchScans),
    );
    if (content == null) return false;
    return _copyText(content, label: 'batch CSV');
  }

  Future<void> shareBatchCsv() async {
    final String? content = _prepareExport(
      'batch CSV',
      () => ReportEncoder.batchCsv(_batchScans),
    );
    if (content == null) return;
    await _shareTextFile(
      filename: 'tagverity-batch-${ReportEncoder.timestampForFilename()}.csv',
      content: content,
      mimeType: 'text/csv',
      subject: 'TagVerity batch scan report',
    );
  }

  String? _prepareExport(String label, String Function() encode) {
    try {
      return encode();
    } on Object catch (error) {
      _setError(
        'Could not prepare $label: ${ErrorText.clean(error)}',
        code: 'export.encode.failed',
        data: <String, Object?>{'label': label},
      );
      return null;
    }
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
    final Map<String, Object?> payload = ReportEncoder.diagnosticsEnvelope(
      supportStatus: _supportStatus,
      isScanning: _isScanning,
      historyCount: _history.length,
      batchCount: _batchScans.length,
      settings: _settings,
      privacySettingsRecoveryRequired: _historyLoadDeferredForSettings,
      diagnostics: _diagnostics,
    );
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
    final String safeMessage = ErrorText.clean(message);
    _errorMessage = safeMessage;
    _addDiagnostic(level, code, safeMessage, data: data);
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
