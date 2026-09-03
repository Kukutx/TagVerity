import '../../domain/models/nfc_scan.dart';
import '../../domain/models/nfc_support_status.dart';
import '../../domain/models/scan_settings.dart';

typedef ScanResultCallback = Future<void> Function(NfcScan scan);
typedef ScanErrorCallback = void Function(String message);

abstract interface class NfcReaderService {
  Future<NfcSupportStatus> checkAvailability();

  Future<void> startScan({
    required ScanSettings settings,
    required ScanResultCallback onScan,
    required ScanErrorCallback onError,
  });

  Future<void> stopScan();
}
