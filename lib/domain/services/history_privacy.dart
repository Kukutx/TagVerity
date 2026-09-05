import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/nfc_scan.dart';

abstract final class HistoryPrivacy {
  static String sessionFingerprint(NfcScan scan) {
    return sha256
        .convert(
          utf8.encode(
            'history|${scan.id}|${scan.scannedAt.toUtc().microsecondsSinceEpoch}|'
            '${scan.platform}',
          ),
        )
        .toString();
  }
}
