import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/ndef_record_info.dart';
import '../../domain/models/nfc_scan.dart';
import '../../domain/models/scan_settings.dart';
import '../../domain/models/tag_fact_catalog.dart';
import '../../domain/models/tag_identity_stability.dart';
import '../../domain/repositories/scan_history_repository.dart';
import '../../domain/services/history_privacy.dart';

final class SharedPreferencesScanHistoryRepository
    implements ScanHistoryRepository {
  SharedPreferencesScanHistoryRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  static const String _historyKey = 'tagverity.history.v2';
  static const String _settingsKey = 'tagverity.settings.v2';
  static const String _legacyHistoryKey = 'nfc_inspector.history.v1';
  static const String _legacySettingsKey = 'nfc_inspector.settings.v1';
  static final RegExp _fingerprintPattern = RegExp(r'^[0-9a-f]{64}$');
  static const Set<String> _scanFields = <String>{
    'id',
    'scannedAt',
    'platform',
    'uidHex',
    'uidFingerprint',
    'identityStability',
    'technologies',
    'details',
    'ndefRecords',
    'warnings',
  };
  static const Set<String> _ndefRecordFields = <String>{
    'index',
    'typeNameFormat',
    'type',
    'identifierHex',
    'payloadLength',
    'byteLength',
    'summary',
    'payloadPreviewHex',
  };
  final SharedPreferencesAsync _preferences;
  @override
  Future<List<NfcScan>> loadHistory() async {
    final String? current = await _preferences.getString(_historyKey);
    if (current != null) {
      if (current.isEmpty) {
        throw const FormatException('Saved scan history is empty or corrupt.');
      }
      final List<NfcScan> history = _decodeHistory(current);
      await _eraseLegacyHistoryCopy();
      return history;
    }
    final String? legacy = await _preferences.getString(_legacyHistoryKey);
    if (legacy == null || legacy.isEmpty) {
      return const <NfcScan>[];
    }
    final List<NfcScan> legacyHistory = _decodeHistory(legacy);
    final List<NfcScan> migrated = <NfcScan>[
      for (final MapEntry<int, NfcScan> entry in legacyHistory.asMap().entries)
        _migrateLegacyScan(entry.value, entry.key),
    ];
    await saveHistory(migrated);
    await _eraseLegacyHistoryCopy();
    return migrated;
  }

  Future<void> _eraseLegacyHistoryCopy() async {
    final String? legacy = await _preferences.getString(_legacyHistoryKey);
    if (legacy == null) {
      return;
    }
    // Once the current history key exists, it is authoritative. Overwrite the
    // stale legacy copy before deletion so a failed remove cannot leave raw
    // UID/NDEF data behind indefinitely.
    await _preferences.setString(_legacyHistoryKey, '[]');
    try {
      await _preferences.remove(_legacyHistoryKey);
    } on Object {
      // The stale key now contains only an empty list, so keeping it is safe.
    }
  }

  NfcScan _migrateLegacyScan(NfcScan scan, int ordinal) {
    final String safeEventId = HistoryPrivacy.safeEventId(
      scan,
      ordinal: ordinal,
    );
    return scan.copyWith(
      id: safeEventId,
      uidHex: null,
      uidFingerprint: HistoryPrivacy.sessionFingerprint(
        scan,
        eventId: safeEventId,
      ),
      identityStability: TagIdentityStability.sessionOnly,
      details: TagFactCatalog.privacyScrubbedDetails(scan.details),
      ndefRecords: const <NdefRecordInfo>[],
      warnings: HistoryPrivacy.safeWarnings(scan.warnings),
    );
  }

  List<NfcScan> _decodeHistory(String encoded) {
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on Object {
      throw const FormatException('Saved scan history is not valid JSON.');
    }
    if (decoded is! List<dynamic>) {
      throw const FormatException('Saved scan history has an invalid shape.');
    }
    final List<NfcScan> scans = <NfcScan>[];
    final Set<String> scanIds = <String>{};
    for (final Object? item in decoded) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'Saved scan history contains an invalid record.',
        );
      }
      _validateScanJson(item);
      final NfcScan scan = NfcScan.fromJson(item);
      if (!scanIds.add(scan.id)) {
        throw const FormatException(
          'Saved scan history contains duplicate scan IDs.',
        );
      }
      scans.add(scan);
    }
    return List<NfcScan>.unmodifiable(scans);
  }

  void _validateScanJson(Map<String, dynamic> json) {
    final Object? id = json['id'];
    final Object? scannedAt = json['scannedAt'];
    final Object? platform = json['platform'];
    final Object? uidHex = json['uidHex'];
    final Object? fingerprint = json['uidFingerprint'];
    final Object? identityStability = json['identityStability'];
    final Object? technologies = json['technologies'];
    final Object? details = json['details'];
    final Object? records = json['ndefRecords'];
    final Object? warnings = json['warnings'];

    final bool invalidIdentity =
        identityStability != null &&
        (identityStability is! String ||
            !const <String>{
              'stable',
              'sessionOnly',
              'unknown',
            }.contains(identityStability));
    final bool invalid =
        json.keys.any((String key) => !_scanFields.contains(key)) ||
        !json.containsKey('uidHex') ||
        id is! String ||
        id.isEmpty ||
        scannedAt is! String ||
        DateTime.tryParse(scannedAt) == null ||
        platform is! String ||
        platform.isEmpty ||
        (uidHex != null &&
            (uidHex is! String ||
                HistoryPrivacy.comparableFingerprintFromUidHex(uidHex) ==
                    null)) ||
        fingerprint is! String ||
        !_fingerprintPattern.hasMatch(fingerprint) ||
        invalidIdentity ||
        technologies is! List<dynamic> ||
        technologies.any((Object? item) => item is! String) ||
        technologies.toSet().length != technologies.length ||
        details is! Map<String, dynamic> ||
        details.values.any((Object? value) => value is! String) ||
        records is! List<dynamic> ||
        records.any(
          (Object? record) =>
              record is! Map<String, dynamic> ||
              !_isValidNdefRecordJson(record),
        ) ||
        records
                .map(
                  (Object? record) =>
                      (record as Map<String, dynamic>)['index'] as int,
                )
                .toSet()
                .length !=
            records.length ||
        warnings is! List<dynamic> ||
        warnings.any((Object? item) => item is! String);

    if (invalid) {
      throw const FormatException(
        'Saved scan history contains an incomplete or invalid record.',
      );
    }
  }

  bool _isValidNdefRecordJson(Map<String, dynamic> json) {
    if (json.keys.any((String key) => !_ndefRecordFields.contains(key))) {
      return false;
    }
    final Object? index = json['index'];
    final Object? typeNameFormat = json['typeNameFormat'];
    final Object? type = json['type'];
    final Object? identifierHex = json['identifierHex'];
    final Object? payloadLength = json['payloadLength'];
    final Object? byteLength = json['byteLength'];
    final Object? summary = json['summary'];
    final Object? payloadPreviewHex = json['payloadPreviewHex'];
    return index is int &&
        index >= 0 &&
        typeNameFormat is String &&
        type is String &&
        identifierHex is String &&
        payloadLength is int &&
        payloadLength >= 0 &&
        byteLength is int &&
        byteLength >= 0 &&
        summary is String &&
        payloadPreviewHex is String;
  }

  void _validateHistoryForSave(List<NfcScan> scans) {
    final Set<String> scanIds = <String>{};
    for (final NfcScan scan in scans) {
      _validateScanJson(scan.toJson());
      if (!scanIds.add(scan.id)) {
        throw const FormatException(
          'Scan history cannot be saved with duplicate scan IDs.',
        );
      }
    }
  }

  @override
  Future<void> saveHistory(List<NfcScan> scans) async {
    _validateHistoryForSave(scans);
    final String encoded = jsonEncode(
      scans.map((NfcScan scan) => scan.toJson()).toList(growable: false),
    );
    await _preferences.setString(_historyKey, encoded);
  }

  @override
  Future<void> clearHistory() async {
    await _preferences.clear(
      allowList: <String>{_historyKey, _legacyHistoryKey},
    );
  }

  @override
  Future<ScanSettings> loadSettings() async {
    final String? current = await _preferences.getString(_settingsKey);
    if (current != null) {
      if (current.isEmpty) {
        throw const FormatException('Saved settings are empty or corrupt.');
      }
      final ScanSettings settings = _decodeSettings(current);
      await _eraseLegacySettingsCopy();
      return settings;
    }
    final String? legacy = await _preferences.getString(_legacySettingsKey);
    if (legacy == null || legacy.isEmpty) {
      return const ScanSettings();
    }
    final ScanSettings migrated = _decodeSettings(legacy);
    await saveSettings(migrated);
    await _eraseLegacySettingsCopy();
    return migrated;
  }

  Future<void> _eraseLegacySettingsCopy() async {
    try {
      final String? legacy = await _preferences.getString(_legacySettingsKey);
      if (legacy == null) {
        return;
      }
      await _preferences.setString(_legacySettingsKey, '{}');
      try {
        await _preferences.remove(_legacySettingsKey);
      } on Object {
        // The stale key now contains no user-selected retention values.
      }
    } on Object {
      // Current settings remain authoritative; cleanup is best-effort only.
    }
  }

  ScanSettings _decodeSettings(String encoded) {
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on Object {
      throw const FormatException('Saved settings are not valid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Saved settings have an invalid shape.');
    }
    for (final String key in const <String>{
      'readNdef',
      'saveRawUidInHistory',
      'saveNdefInHistory',
      'saveTechnicalIdentifiersInHistory',
    }) {
      final Object? value = decoded[key];
      if (value != null && value is! bool) {
        throw FormatException('Saved setting "$key" is not a boolean.');
      }
    }
    return ScanSettings.fromJson(decoded);
  }

  @override
  Future<void> saveSettings(ScanSettings settings) async {
    await _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}
