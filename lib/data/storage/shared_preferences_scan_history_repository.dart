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
    if (current != null && current.isNotEmpty) {
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
    final String id = json['id'] as String? ?? '';
    final String scannedAt = json['scannedAt'] as String? ?? '';
    final String platform = json['platform'] as String? ?? '';
    final String fingerprint = json['uidFingerprint'] as String? ?? '';
    if (id.isEmpty ||
        DateTime.tryParse(scannedAt) == null ||
        platform.isEmpty ||
        fingerprint.isEmpty ||
        json['technologies'] is! List<dynamic> ||
        json['details'] is! Map<String, dynamic> ||
        json['ndefRecords'] is! List<dynamic> ||
        json['warnings'] is! List<dynamic>) {
      throw const FormatException(
        'Saved scan history contains an incomplete record.',
      );
    }
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
    await _preferences.remove(_historyKey);
    await _preferences.remove(_legacyHistoryKey);
  }

  @override
  Future<ScanSettings> loadSettings() async {
    final String? current = await _preferences.getString(_settingsKey);
    if (current != null && current.isNotEmpty) {
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
    return ScanSettings.fromJson(decoded);
  }

  @override
  Future<void> saveSettings(ScanSettings settings) async {
    await _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}
