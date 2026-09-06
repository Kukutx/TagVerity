import '../models/ndef_record_info.dart';
import '../models/nfc_scan.dart';
import 'history_privacy.dart';

abstract final class ScanContract {
  static const String _fingerprintPatternSource = r'^[0-9a-f]{64}$';
  static const String _uidHexPatternSource =
      r'^(?:[0-9A-Fa-f]{2})(?::[0-9A-Fa-f]{2})*$';
  static const String _colonHexPatternSource =
      r'^(?:[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2})*)?$';
  static const int _maximumPayloadPreviewBytes = 64;

  static final RegExp _fingerprintPattern = RegExp(_fingerprintPatternSource);
  static final RegExp _uidHexPattern = RegExp(_uidHexPatternSource);
  static final RegExp _colonHexPattern = RegExp(_colonHexPatternSource);

  static void validate(NfcScan scan) {
    if (scan.id.isEmpty || scan.platform.isEmpty) {
      throw const FormatException('Scan identity metadata is incomplete.');
    }
    if (!_fingerprintPattern.hasMatch(scan.uidFingerprint)) {
      throw const FormatException(
        'Scan fingerprint is not a lowercase SHA-256 value.',
      );
    }
    final String? uidHex = scan.uidHex;
    if (uidHex != null) {
      if (!_uidHexPattern.hasMatch(uidHex)) {
        throw const FormatException(
          'Scan UID is not byte-formatted hexadecimal.',
        );
      }
      final String? expectedFingerprint =
          HistoryPrivacy.comparableFingerprintFromUidHex(uidHex);
      if (!scan.hasComparableIdentity ||
          expectedFingerprint != scan.uidFingerprint) {
        throw const FormatException(
          'Scan raw UID and comparable identity metadata are inconsistent.',
        );
      }
    }
    if (scan.technologies.toSet().length != scan.technologies.length) {
      throw const FormatException('Scan technologies contain duplicates.');
    }
    for (final MapEntry<int, NdefRecordInfo> entry
        in scan.ndefRecords.asMap().entries) {
      final NdefRecordInfo record = entry.value;
      if (record.index != entry.key ||
          record.payloadLength < 0 ||
          record.byteLength < record.payloadLength ||
          !_colonHexPattern.hasMatch(record.identifierHex) ||
          !_colonHexPattern.hasMatch(record.payloadPreviewHex)) {
        throw const FormatException('Scan NDEF record metadata is invalid.');
      }
      final int expectedPreviewBytes =
          record.payloadLength < _maximumPayloadPreviewBytes
          ? record.payloadLength
          : _maximumPayloadPreviewBytes;
      if (_hexByteCount(record.payloadPreviewHex) != expectedPreviewBytes) {
        throw const FormatException(
          'Scan NDEF payload preview length is inconsistent.',
        );
      }
    }
  }

  static void validateAll(Iterable<NfcScan> scans) {
    final Set<String> scanIds = <String>{};
    for (final NfcScan scan in scans) {
      validate(scan);
      if (!scanIds.add(scan.id)) {
        throw const FormatException('Scan collection contains duplicate IDs.');
      }
    }
  }

  static int _hexByteCount(String value) =>
      value.isEmpty ? 0 : value.split(':').length;
}
