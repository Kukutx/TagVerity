import 'package:flutter/material.dart';

import '../../domain/models/tag_assessment.dart';
import 'section_card.dart';

class TagAssessmentCard extends StatelessWidget {
  const TagAssessmentCard({
    required this.assessment,
    this.compact = false,
    super.key,
  });

  final TagAssessment assessment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final (IconData, Color, String) presentation = switch (assessment.status) {
      TagAssessmentStatus.healthy => (
        Icons.verified_rounded,
        colors.primary,
        'PASS',
      ),
      TagAssessmentStatus.limited => (
        Icons.info_rounded,
        colors.tertiary,
        'LIMITED',
      ),
      TagAssessmentStatus.review => (
        Icons.warning_amber_rounded,
        colors.error,
        'REVIEW',
      ),
    };

    return SectionCard(
      title: 'Tag check',
      trailing: DecoratedBox(
        decoration: BoxDecoration(
          color: presentation.$2.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            presentation.$3,
            style: TextStyle(
              color: presentation.$2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(presentation.$1, color: presentation.$2, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      assessment.headline,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(assessment.summary),
                  ],
                ),
              ),
            ],
          ),
          if (!compact) ...<Widget>[
            const SizedBox(height: 14),
            ...assessment.items.map(
              (TagCheckItem item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(switch (item.state) {
                      TagCheckState.passed =>
                        Icons.check_circle_outline_rounded,
                      TagCheckState.info => Icons.info_outline_rounded,
                      TagCheckState.warning => Icons.warning_amber_rounded,
                    }, size: 19),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: '${item.title}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: item.detail),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
