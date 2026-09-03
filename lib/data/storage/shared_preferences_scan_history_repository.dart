import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
            details: TagFactCatalog.privacyScrubbedDetails(scan.details),
          ),
        )
        .toList(growable: false);
    await saveHistory(migrated);
    await _preferences.remove(_legacyHistoryKey);
    return migrated;
  }

  List<NfcScan> _decodeHistory(String encoded) {
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! List<dynamic>) {
        return const <NfcScan>[];
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(NfcScan.fromJson)
          .toList(growable: false);
    } on Object {
      return const <NfcScan>[];
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
    try {
      final Object? decoded = jsonDecode(encoded);
      return decoded is Map<String, dynamic>
          ? ScanSettings.fromJson(decoded)
          : const ScanSettings();
    } on Object {
      return const ScanSettings();
    }
  }

  @override
  Future<void> saveSettings(ScanSettings settings) async {
    await _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}
