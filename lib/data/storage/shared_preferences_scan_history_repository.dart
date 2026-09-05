import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/ndef_record_info.dart';
import '../../domain/models/nfc_scan.dart';
import '../../domain/models/scan_settings.dart';
import '../../domain/models/tag_fact_catalog.dart';
import '../../domain/repositories/scan_history_repository.dart';

final class SharedPreferencesScanHistoryRepository
    implements ScanHistoryRepository {
  SharedPreferencesScanHistoryRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  static const String _historyKey = 'tagverity.history.v2';
  static const String _settingsKey = 'tagverity.settings.v2';
  static const String _legacyHistoryKey = 'nfc_inspector.history.v1';
  static const String _legacySettingsKey = 'nfc_inspector.settings.v1';
  final SharedPreferencesAsync _preferences;
  @override
  Future<List<NfcScan>> loadHistory() async {
    final String? current = await _preferences.getString(_historyKey);
    if (current != null) {
      if (current.isEmpty) {
        throw const FormatException('Saved scan history is empty or corrupt.');
      }
      return _decodeHistory(current);
    }
    final String? legacy = await _preferences.getString(_legacyHistoryKey);
    if (legacy == null || legacy.isEmpty) {
      return const <NfcScan>[];
    }
    final List<NfcScan> migrated = _decodeHistory(legacy)
        .map(
          (NfcScan scan) => scan.copyWith(
            uidHex: null,
            details: TagFactCatalog.privacyScrubbedDetails(scan.details),
            ndefRecords: const <NdefRecordInfo>[],
          ),
        )
        .toList(growable: false);
    await saveHistory(migrated);
    await _preferences.remove(_legacyHistoryKey);
    return migrated;
  }

  List<NfcScan> _decodeHistory(String encoded) {
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on Object catch (error) {
      throw FormatException('Saved scan history is not valid JSON: $error');
    }
    if (decoded is! List<dynamic>) {
      throw const FormatException('Saved scan history has an invalid shape.');
    }
    final List<NfcScan> scans = <NfcScan>[];
    for (final Object? item in decoded) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'Saved scan history contains an invalid record.',
        );
      }
      _validateScanJson(item);
      scans.add(NfcScan.fromJson(item));
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
        id is! String ||
        id.isEmpty ||
        scannedAt is! String ||
        DateTime.tryParse(scannedAt) == null ||
        platform is! String ||
        platform.isEmpty ||
        (uidHex != null && uidHex is! String) ||
        fingerprint is! String ||
        fingerprint.isEmpty ||
        invalidIdentity ||
        technologies is! List<dynamic> ||
        technologies.any((Object? item) => item is! String) ||
        details is! Map<String, dynamic> ||
        details.values.any((Object? value) => value is! String) ||
        records is! List<dynamic> ||
        records.any(
          (Object? record) =>
              record is! Map<String, dynamic> ||
              !_isValidNdefRecordJson(record),
        ) ||
        warnings is! List<dynamic> ||
        warnings.any((Object? item) => item is! String);

    if (invalid) {
      throw const FormatException(
        'Saved scan history contains an incomplete or invalid record.',
      );
    }
  }

  bool _isValidNdefRecordJson(Map<String, dynamic> json) {
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

  @override
  Future<void> saveHistory(List<NfcScan> scans) async {
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
      return _decodeSettings(current);
    }
    final String? legacy = await _preferences.getString(_legacySettingsKey);
    if (legacy == null || legacy.isEmpty) {
      return const ScanSettings();
    }
    final ScanSettings migrated = _decodeSettings(legacy);
    await saveSettings(migrated);
    await _preferences.remove(_legacySettingsKey);
    return migrated;
  }

  ScanSettings _decodeSettings(String encoded) {
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on Object catch (error) {
      throw FormatException('Saved settings are not valid JSON: $error');
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
