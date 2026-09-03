import '../models/nfc_scan.dart';
import '../models/tag_assessment.dart';

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

    if (scan.uidHex == null) {
      items.add(
        const TagCheckItem(
          title: 'Tag identifier',
          detail: 'A raw identifier is not available in this view.',
          state: TagCheckState.info,
        ),
      );
    } else {
      items.add(
        const TagCheckItem(
          title: 'Tag identifier',
          detail: 'A tag identifier was exposed for this scan.',
          state: TagCheckState.passed,
        ),
      );
    }

    final String? ndefSupport = scan.details['ndef.supported'];
    if (ndefSupport == 'yes') {
      final int recordCount =
          int.tryParse(scan.details['ndef.recordCount'] ?? '') ??
          scan.ndefRecords.length;
      items.add(
        TagCheckItem(
          title: 'NDEF',
          detail: recordCount == 0
              ? 'Standard NDEF is available, but no records were found.'
              : '$recordCount standard NDEF record${recordCount == 1 ? '' : 's'} found.',
          state: recordCount == 0 ? TagCheckState.info : TagCheckState.passed,
        ),
      );
    } else if (ndefSupport == 'no') {
      items.add(
        const TagCheckItem(
          title: 'NDEF',
          detail: 'This tag does not expose a standard NDEF container.',
          state: TagCheckState.info,
        ),
      );
    }

    if (scan.warnings.isEmpty) {
      items.add(
        const TagCheckItem(
          title: 'Read quality',
          detail: 'No read warnings were reported.',
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
    final bool limited = !hasWarnings && ndefSupport == 'no';

    if (hasWarnings) {
      return TagAssessment(
        status: TagAssessmentStatus.review,
        headline: 'Review this tag',
        summary: 'The tag was detected, but one or more checks need attention.',
        items: List<TagCheckItem>.unmodifiable(items),
      );
    }
    if (limited) {
      return TagAssessment(
        status: TagAssessmentStatus.limited,
        headline: 'Readable with limits',
        summary:
            'The tag responded normally but does not expose standard NDEF.',
        items: List<TagCheckItem>.unmodifiable(items),
      );
    }
    return TagAssessment(
      status: TagAssessmentStatus.healthy,
      headline: 'Basic checks passed',
      summary:
          'The tag was read successfully with no basic inspection warnings.',
      items: List<TagCheckItem>.unmodifiable(items),
    );
  }
}
