import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/nfc_scan.dart';

abstract final class HistoryPrivacy {
  static final RegExp _legacyLinkableEventId = RegExp(r'^\d+-[0-9a-fA-F]{12}$');
  static final RegExp _uidBytePattern = RegExp(r'^[0-9A-Fa-f]{2}$');

  static bool eventIdNeedsScrub(String id) =>
      _legacyLinkableEventId.hasMatch(id);

  static String safeEventId(NfcScan scan, {int? ordinal}) {
    if (!eventIdNeedsScrub(scan.id)) {
      return scan.id;
    }
    final int timestamp = scan.scannedAt.toUtc().microsecondsSinceEpoch;
    final String suffix = ordinal == null
        ? 'migrated'
        : 'migrated-${ordinal + 1}';
    return 'scan-$timestamp-$suffix';
  }

  static String? comparableFingerprintFromUidHex(String? uidHex) {
    if (uidHex == null || uidHex.isEmpty) {
      return null;
    }
    final List<String> parts = uidHex.split(':');
    if (parts.isEmpty ||
        parts.any((String part) => !_uidBytePattern.hasMatch(part))) {
      return null;
    }
    final List<int> bytes = parts
        .map((String part) => int.parse(part, radix: 16))
        .toList(growable: false);
    return sha256.convert(bytes).toString();
  }

  static String sessionFingerprint(NfcScan scan, {String? eventId}) {
    final String safeId = eventId ?? safeEventId(scan);
    return sha256
        .convert(
          utf8.encode(
            'history|$safeId|${scan.scannedAt.toUtc().microsecondsSinceEpoch}|'
            '${scan.platform}',
          ),
        )
        .toString();
  }

  static List<String> safeWarnings(Iterable<String> warnings) {
    return warnings.map(safeWarning).toList(growable: false);
  }

  static String safeWarning(String warning) {
    final String value = warning.trim();
    if (_safeHistoryWarnings.contains(value)) {
      return value;
    }
    if (value.startsWith('Could not read standard NDEF')) {
      return 'Could not read standard NDEF.';
    }
    if (value.startsWith('Could not read iOS MIFARE metadata')) {
      return 'Could not read optional iOS MIFARE metadata.';
    }
    if (value.startsWith('Could not read iOS ISO 7816 metadata')) {
      return 'Could not read optional iOS ISO 7816 metadata.';
    }
    if (value.contains('read failed:')) {
      return 'Optional NFC metadata read failed.';
    }
    if (value.startsWith('iOS did not expose a tag identifier')) {
      return 'iOS did not expose a comparable tag identifier.';
    }
    return 'A scan warning was reported.';
  }

  static const Set<String> _safeHistoryWarnings = <String>{
    'Could not read standard NDEF.',
    'Could not read optional iOS MIFARE metadata.',
    'Could not read optional iOS ISO 7816 metadata.',
    'Optional NFC metadata read failed.',
    'iOS did not expose a comparable tag identifier.',
    'A scan warning was reported.',
  };

  static bool warningsNeedScrub(Iterable<String> warnings) {
    return warnings.any((String warning) => safeWarning(warning) != warning);
  }
}
