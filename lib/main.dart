import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/export/share_export_service.dart';
import 'data/nfc/nfc_manager_reader_service.dart';
import 'data/storage/shared_preferences_scan_history_repository.dart';
import 'presentation/controllers/nfc_scan_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final NfcScanController controller = NfcScanController(
    readerService: NfcManagerReaderService(),
    repository: SharedPreferencesScanHistoryRepository(),
    exportService: ShareExportService(),
  );

  await controller.initialize();
  runApp(TagVerityApp(controller: controller));
}
