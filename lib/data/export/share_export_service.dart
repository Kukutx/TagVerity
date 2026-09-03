import 'package:flutter/services.dart';

import '../../domain/services/export_service.dart';

final class ShareExportService implements ExportService {
  static const MethodChannel _channel = MethodChannel(
    'dev.kukutx.tagverity/share',
  );

  @override
  Future<void> shareTextFile({
    required String filename,
    required String content,
    required String mimeType,
    required String subject,
  }) async {
    await _channel.invokeMethod<void>('shareTextFile', <String, String>{
      'filename': filename,
      'content': content,
      'mimeType': mimeType,
      'subject': subject,
    });
  }
}
