import '../models/nfc_scan.dart';
import '../models/scan_settings.dart';

abstract interface class ScanHistoryRepository {
  Future<List<NfcScan>> loadHistory();

  Future<void> saveHistory(List<NfcScan> scans);

  Future<void> clearHistory();

  Future<ScanSettings> loadSettings();

  Future<void> saveSettings(ScanSettings settings);
}
