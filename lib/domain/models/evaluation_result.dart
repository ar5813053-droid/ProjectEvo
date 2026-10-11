class EvaluationResult {
  final double score;
  final bool factualConsistencyOk;
  final bool relevant;
  final bool uncertaintyHandled;
  final List<String> issues;
  final String summary;

  const EvaluationResult({
    required this.score,
    required this.factualConsistencyOk,
    required this.relevant,
    required this.uncertaintyHandled,
    this.issues = const [],
    required this.summary,
  });
}
