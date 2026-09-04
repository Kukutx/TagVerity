import '../models/nfc_scan.dart';
import '../models/tag_classification.dart';

abstract final class TagClassifier {
  static TagClassification classify(NfcScan scan) {
    final Map<String, String> details = scan.details;

    if (details['mifare.classic.type'] case final String type) {
      return TagClassification(
        label: 'MIFARE Classic',
        detail: 'Android reported MIFARE Classic ($type).',
        confidence: TagClassificationConfidence.high,
      );
    }

    if (details['mifare.ultralight.type'] case final String type) {
      return TagClassification(
        label: 'MIFARE Ultralight-compatible',
        detail:
            'Android reported the MIFARE Ultralight technology family ($type). '
            'TagVerity does not guess an exact chip model from this alone.',
        confidence: TagClassificationConfidence.high,
      );
    }

    if (details['ios.mifare.family'] case final String family) {
      return TagClassification(
        label: 'MIFARE-compatible',
        detail: 'iOS reported the MIFARE family as $family.',
        confidence: TagClassificationConfidence.high,
      );
    }

    if (details['isodep.supported'] == 'yes' ||
        details['ios.iso7816.supported'] == 'yes') {
      return const TagClassification(
        label: 'ISO-DEP / smart card',
        detail:
            'The tag exposes ISO 14443-4 / ISO 7816 style communication. '
            'This does not identify a proprietary application or credential.',
        confidence: TagClassificationConfidence.medium,
      );
    }

    final String protocol = details['protocol'] ?? '';
    if (protocol.contains('NFC-B')) {
      return const TagClassification(
        label: 'NFC-B tag',
        detail: 'The operating system reported ISO 14443-3B.',
        confidence: TagClassificationConfidence.high,
      );
    }

    if (details['ndef.supported'] == 'yes') {
      return const TagClassification(
        label: 'NDEF NFC tag',
        detail:
            'The tag exposes a standard NDEF container. The exact chip model '
            'cannot be proven from NDEF support alone.',
        confidence: TagClassificationConfidence.medium,
      );
    }

    final Set<String> technologies = scan.technologies
        .map((String value) => value.toLowerCase())
        .toSet();
    if (technologies.any((String value) => value.contains('nfca'))) {
      return const TagClassification(
        label: 'NFC-A tag',
        detail: 'The operating system reported NFC-A / ISO 14443-A.',
        confidence: TagClassificationConfidence.medium,
      );
    }
    if (technologies.any((String value) => value.contains('nfcb'))) {
      return const TagClassification(
        label: 'NFC-B tag',
        detail: 'The operating system reported NFC-B / ISO 14443-B.',
        confidence: TagClassificationConfidence.medium,
      );
    }

    if (scan.technologies.isEmpty) {
      return const TagClassification(
        label: 'Unknown NFC tag',
        detail: 'The operating system did not expose enough data to classify it.',
        confidence: TagClassificationConfidence.low,
      );
    }

    return TagClassification(
      label: 'NFC tag',
      detail:
          'Observed technologies: ${scan.technologies.join(', ')}. '
          'TagVerity avoids guessing a chip model without stronger evidence.',
      confidence: TagClassificationConfidence.low,
    );
  }
}
