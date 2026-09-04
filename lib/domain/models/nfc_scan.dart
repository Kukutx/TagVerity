import 'ndef_record_info.dart';
import 'tag_identity_stability.dart';

class NfcScan {
  const NfcScan({
    required this.id,
    required this.scannedAt,
    required this.platform,
    required this.uidFingerprint,
    required this.technologies,
    required this.details,
    required this.ndefRecords,
    required this.warnings,
    this.uidHex,
    this.identityStability = TagIdentityStability.unknown,
  });

  final String id;
  final DateTime scannedAt;
  final String platform;
  final String? uidHex;
  final String uidFingerprint;
  final TagIdentityStability identityStability;
  final List<String> technologies;
  final Map<String, String> details;
  final List<NdefRecordInfo> ndefRecords;
  final List<String> warnings;

  bool get hasComparableIdentity => identityStability.isComparable;

  NfcScan copyWith({
    String? id,
    DateTime? scannedAt,
    String? platform,
    Object? uidHex = _sentinel,
    String? uidFingerprint,
    TagIdentityStability? identityStability,
    List<String>? technologies,
    Map<String, String>? details,
    List<NdefRecordInfo>? ndefRecords,
    List<String>? warnings,
  }) {
    return NfcScan(
      id: id ?? this.id,
      scannedAt: scannedAt ?? this.scannedAt,
      platform: platform ?? this.platform,
      uidHex: identical(uidHex, _sentinel) ? this.uidHex : uidHex as String?,
      uidFingerprint: uidFingerprint ?? this.uidFingerprint,
      identityStability: identityStability ?? this.identityStability,
      technologies: technologies ?? this.technologies,
      details: details ?? this.details,
      ndefRecords: ndefRecords ?? this.ndefRecords,
      warnings: warnings ?? this.warnings,
    );
  }

  Map<String, Object?> toJson({bool includeRawUid = true}) => <String, Object?>{
    'id': id,
    'scannedAt': scannedAt.toUtc().toIso8601String(),
    'platform': platform,
    'uidHex': includeRawUid ? uidHex : null,
    'uidFingerprint': uidFingerprint,
    'identityStability': identityStability.name,
    'technologies': technologies,
    'details': details,
    'ndefRecords': ndefRecords
        .map((NdefRecordInfo record) => record.toJson())
        .toList(),
    'warnings': warnings,
  };

  factory NfcScan.fromJson(Map<String, dynamic> json) {
    final Object? technologiesValue = json['technologies'];
    final Object? detailsValue = json['details'];
    final Object? recordsValue = json['ndefRecords'];
    final Object? warningsValue = json['warnings'];

    return NfcScan(
      id: json['id'] as String? ?? '',
      scannedAt:
          DateTime.tryParse(json['scannedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      platform: json['platform'] as String? ?? 'unknown',
      uidHex: json['uidHex'] as String?,
      uidFingerprint: json['uidFingerprint'] as String? ?? '',
      identityStability: _identityStabilityFromJson(
        json['identityStability'] as String?,
      ),
      technologies: technologiesValue is List<dynamic>
          ? technologiesValue.whereType<String>().toList(growable: false)
          : const <String>[],
      details: detailsValue is Map<String, dynamic>
          ? detailsValue.map(
              (String key, dynamic value) =>
                  MapEntry<String, String>(key, value.toString()),
            )
          : const <String, String>{},
      ndefRecords: recordsValue is List<dynamic>
          ? recordsValue
                .whereType<Map<String, dynamic>>()
                .map(NdefRecordInfo.fromJson)
                .toList(growable: false)
          : const <NdefRecordInfo>[],
      warnings: warningsValue is List<dynamic>
          ? warningsValue.whereType<String>().toList(growable: false)
          : const <String>[],
    );
  }

  static TagIdentityStability _identityStabilityFromJson(String? value) {
    for (final TagIdentityStability item in TagIdentityStability.values) {
      if (item.name == value) {
        return item;
      }
    }
    return TagIdentityStability.unknown;
  }

  static const Object _sentinel = Object();
}
