enum TagClassificationConfidence { high, medium, low }

class TagClassification {
  const TagClassification({
    required this.label,
    required this.detail,
    required this.confidence,
  });

  final String label;
  final String detail;
  final TagClassificationConfidence confidence;
}
