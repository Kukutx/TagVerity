import '../models/nfc_scan.dart';
import '../models/tag_assessment.dart';
import '../models/tag_identity_stability.dart';

abstract final class TagAssessor {
  static TagAssessment assess(NfcScan scan) {
    final List<TagCheckItem> items = <TagCheckItem>[];
    if (scan.technologies.isEmpty) {
      items.add(
        const TagCheckItem(
          title: 'Tag technology',
          detail: 'The operating system did not expose a technology stack.',
          state: TagCheckState.warning,
        ),
      );
    } else {
      items.add(
        TagCheckItem(
          title: 'Tag detected',
          detail: scan.technologies.join(', '),
          state: TagCheckState.passed,
        ),
      );
    }
    switch (scan.identityStability) {
      case TagIdentityStability.stable:
        items.add(
          const TagCheckItem(
            title: 'Tag identity',
            detail:
                'A platform-exposed identifier is available for comparison. '
                'Some tags can randomize identifiers between scans.',
            state: TagCheckState.passed,
          ),
        );
      case TagIdentityStability.sessionOnly:
        items.add(
          const TagCheckItem(
            title: 'Tag identity',
            detail:
                'This platform did not expose a comparable identifier. '
                'Repeated-ID checks are unavailable for this scan.',
            state: TagCheckState.info,
          ),
        );
      case TagIdentityStability.unknown:
        items.add(
          const TagCheckItem(
            title: 'Tag identity',
            detail: 'Identity comparability is unknown for this saved scan.',
            state: TagCheckState.info,
          ),
        );
    }
    final String? ndefSupport = scan.details['ndef.supported'];
    final String? ndefReadStatus = scan.details['ndef.readStatus'];
    if (ndefSupport == 'yes') {
      final int recordCount =
          int.tryParse(scan.details['ndef.recordCount'] ?? '') ??
          scan.ndefRecords.length;
      final (String, TagCheckState) presentation = switch (ndefReadStatus) {
        'error' => (
          'The NDEF container was detected, but its content could not be read.',
          TagCheckState.warning,
        ),
        'disabled' => (
          'NDEF is available, but content reading is disabled in Settings.',
          TagCheckState.info,
        ),
        _ when recordCount == 0 => (
          'Standard NDEF is available and currently empty.',
          TagCheckState.info,
        ),
        _ => (
          '$recordCount standard NDEF record${recordCount == 1 ? '' : 's'} found.',
          TagCheckState.passed,
        ),
      };
      items.add(
        TagCheckItem(
          title: 'NDEF',
          detail: presentation.$1,
          state: presentation.$2,
        ),
      );
    } else if (ndefSupport == 'no') {
      items.add(
        const TagCheckItem(
          title: 'NDEF',
          detail:
              'No standard NDEF container was exposed. This is normal for '
              'many smart cards and protocol-specific NFC tags.',
          state: TagCheckState.info,
        ),
      );
    } else {
      items.add(
        const TagCheckItem(
          title: 'NDEF',
          detail: 'NDEF support was not recorded for this scan.',
          state: TagCheckState.info,
        ),
      );
    }
    if (scan.warnings.isEmpty) {
      items.add(
        const TagCheckItem(
          title: 'Read quality',
          detail: 'No core read warnings were reported.',
          state: TagCheckState.passed,
        ),
      );
    } else {
      items.add(
        TagCheckItem(
          title: 'Read quality',
          detail:
              '${scan.warnings.length} warning${scan.warnings.length == 1 ? '' : 's'} need review.',
          state: TagCheckState.warning,
        ),
      );
    }
    final bool hasWarnings = items.any(
      (TagCheckItem item) => item.state == TagCheckState.warning,
    );
    if (hasWarnings) {
      return TagAssessment(
        status: TagAssessmentStatus.review,
        headline: 'Review this scan',
        summary:
            'The tag was detected, but one or more core checks need attention.',
        items: List<TagCheckItem>.unmodifiable(items),
      );
    }
    if (ndefSupport == 'yes' && ndefReadStatus == 'disabled') {
      return TagAssessment(
        status: TagAssessmentStatus.limited,
        headline: 'Readable with limits',
        summary: 'The tag was read successfully, but NDEF content reading is disabled.',
        items: List<TagCheckItem>.unmodifiable(items),
      );
    }
    return TagAssessment(
      status: TagAssessmentStatus.healthy,
      headline: 'Basic checks passed',
      summary:
          'The tag was read successfully with no core inspection warnings.',
      items: List<TagCheckItem>.unmodifiable(items),
    );
  }
}
