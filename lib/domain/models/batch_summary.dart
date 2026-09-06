import '../services/tag_assessor.dart';
import 'nfc_scan.dart';
import 'tag_assessment.dart';
import 'tag_identity_stability.dart';

final class BatchSummary {
  const BatchSummary({
    required this.total,
    required this.healthy,
    required this.limited,
    required this.review,
    required this.comparable,
    required this.sessionOnly,
    required this.unknownIdentity,
    required this.distinctComparableIds,
    required this.repeatedFingerprints,
  });

  factory BatchSummary.fromScans(Iterable<NfcScan> scans) {
    int total = 0;
    int healthy = 0;
    int limited = 0;
    int review = 0;
    int comparable = 0;
    int sessionOnly = 0;
    int unknownIdentity = 0;
    final Map<String, int> identityCounts = <String, int>{};
    for (final NfcScan scan in scans) {
      total++;
      switch (TagAssessor.assess(scan).status) {
        case TagAssessmentStatus.healthy:
          healthy++;
        case TagAssessmentStatus.limited:
          limited++;
        case TagAssessmentStatus.review:
          review++;
      }
      switch (scan.identityStability) {
        case TagIdentityStability.stable:
          comparable++;
          identityCounts.update(
            scan.uidFingerprint,
            (int value) => value + 1,
            ifAbsent: () => 1,
          );
        case TagIdentityStability.sessionOnly:
          sessionOnly++;
        case TagIdentityStability.unknown:
          unknownIdentity++;
      }
    }
    final Set<String> repeatedFingerprints = identityCounts.entries
        .where((MapEntry<String, int> entry) => entry.value > 1)
        .map((MapEntry<String, int> entry) => entry.key)
        .toSet();
    return BatchSummary(
      total: total,
      healthy: healthy,
      limited: limited,
      review: review,
      comparable: comparable,
      sessionOnly: sessionOnly,
      unknownIdentity: unknownIdentity,
      distinctComparableIds: identityCounts.length,
      repeatedFingerprints: Set<String>.unmodifiable(repeatedFingerprints),
    );
  }

  static const BatchSummary empty = BatchSummary(
    total: 0,
    healthy: 0,
    limited: 0,
    review: 0,
    comparable: 0,
    sessionOnly: 0,
    unknownIdentity: 0,
    distinctComparableIds: 0,
    repeatedFingerprints: <String>{},
  );

  final int total;
  final int healthy;
  final int limited;
  final int review;
  final int comparable;
  final int sessionOnly;
  final int unknownIdentity;
  final int distinctComparableIds;
  final Set<String> repeatedFingerprints;

  int get repeatedIdCount => repeatedFingerprints.length;
}
