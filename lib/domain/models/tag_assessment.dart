enum TagAssessmentStatus { healthy, review, limited }

enum TagCheckState { passed, info, warning }

class TagCheckItem {
  const TagCheckItem({
    required this.title,
    required this.detail,
    required this.state,
  });

  final String title;
  final String detail;
  final TagCheckState state;
}

class TagAssessment {
  const TagAssessment({
    required this.status,
    required this.headline,
    required this.summary,
    required this.items,
  });

  final TagAssessmentStatus status;
  final String headline;
  final String summary;
  final List<TagCheckItem> items;

  int get warningCount => items
      .where((TagCheckItem item) => item.state == TagCheckState.warning)
      .length;
}
