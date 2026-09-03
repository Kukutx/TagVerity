class NdefRecordInfo {
  const NdefRecordInfo({
    required this.index,
    required this.typeNameFormat,
    required this.type,
    required this.identifierHex,
    required this.payloadLength,
    required this.byteLength,
    required this.summary,
    required this.payloadPreviewHex,
  });

  final int index;
  final String typeNameFormat;
  final String type;
  final String identifierHex;
  final int payloadLength;
  final int byteLength;
  final String summary;
  final String payloadPreviewHex;

  Map<String, Object?> toJson() => <String, Object?>{
    'index': index,
    'typeNameFormat': typeNameFormat,
    'type': type,
    'identifierHex': identifierHex,
    'payloadLength': payloadLength,
    'byteLength': byteLength,
    'summary': summary,
    'payloadPreviewHex': payloadPreviewHex,
  };

  factory NdefRecordInfo.fromJson(Map<String, dynamic> json) {
    return NdefRecordInfo(
      index: json['index'] as int? ?? 0,
      typeNameFormat: json['typeNameFormat'] as String? ?? 'unknown',
      type: json['type'] as String? ?? '',
      identifierHex: json['identifierHex'] as String? ?? '',
      payloadLength: json['payloadLength'] as int? ?? 0,
      byteLength: json['byteLength'] as int? ?? 0,
      summary: json['summary'] as String? ?? '',
      payloadPreviewHex: json['payloadPreviewHex'] as String? ?? '',
    );
  }
}
