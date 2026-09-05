import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/tag_classification.dart';
import 'package:tagverity/domain/services/tag_classifier.dart';

void main() {
  test('classifies explicit MIFARE Classic metadata with high confidence', () {
    final TagClassification result = TagClassifier.classify(
      _scan(
        details: const <String, String>{'mifare.classic.type': 'classic1k'},
      ),
    );
    expect(result.label, 'MIFARE Classic');
    expect(result.confidence, TagClassificationConfidence.high);
  });
  test('classifies ISO-DEP without guessing a proprietary application', () {
    final TagClassification result = TagClassifier.classify(
      _scan(details: const <String, String>{'isodep.supported': 'yes'}),
    );
    expect(result.label, 'ISO-DEP / smart card');
    expect(result.confidence, TagClassificationConfidence.medium);
    expect(result.detail, contains('does not identify'));
  });
  test('classifies NFC-V / ISO 15693 metadata', () {
    final TagClassification result = TagClassifier.classify(
      _scan(details: const <String, String>{'nfcv.dsfId': '0x00'}),
    );
    expect(result.label, 'NFC-V / ISO 15693');
    expect(result.confidence, TagClassificationConfidence.high);
  });
  test('classifies NFC-F / FeliCa metadata', () {
    final TagClassification result = TagClassifier.classify(
      _scan(details: const <String, String>{'nfcf.systemCode': '12:FC'}),
    );
    expect(result.label, 'NFC-F / FeliCa-compatible');
    expect(result.confidence, TagClassificationConfidence.high);
  });
  test('classifies generic NDEF tags conservatively', () {
    final TagClassification result = TagClassifier.classify(
      _scan(details: const <String, String>{'ndef.supported': 'yes'}),
    );
    expect(result.label, 'NDEF NFC tag');
    expect(result.confidence, TagClassificationConfidence.medium);
  });
  test('returns unknown when the OS exposes no usable technology', () {
    final TagClassification result = TagClassifier.classify(
      _scan(technologies: const <String>[]),
    );
    expect(result.label, 'Unknown NFC tag');
    expect(result.confidence, TagClassificationConfidence.low);
  });
}

NfcScan _scan({
  List<String> technologies = const <String>['NfcA'],
  Map<String, String> details = const <String, String>{},
}) {
  return NfcScan(
    id: 'scan',
    scannedAt: DateTime.utc(2026, 9, 4),
    platform: 'android',
    uidFingerprint: 'fingerprint',
    technologies: technologies,
    details: details,
    ndefRecords: const [],
    warnings: const [],
  );
}
