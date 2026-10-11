import '../../domain/models/evaluation_result.dart';

/// Lightweight heuristic evaluation — not proof of correctness.
class EvaluationEngine {
  EvaluationResult evaluate({
    required String userMessage,
    required String assistantReply,
    required bool usedMemory,
  }) {
    final issues = <String>[];
    var score = 0.7;

    if (assistantReply.trim().isEmpty) {
      issues.add('Empty reply');
      score = 0.0;
    }
    if (assistantReply.toLowerCase().contains('i am conscious') ||
        assistantReply.toLowerCase().contains('i have feelings')) {
      issues.add('Unsafe claim about consciousness/emotions');
      score -= 0.4;
    }
    if (userMessage.length > 10 && assistantReply.length < 8) {
      issues.add('Reply may be too short for the question');
      score -= 0.1;
    }
    if (assistantReply.contains('ACK_SAVE_MEMORY')) {
      // Internal signal, should be intercepted — flag if leaked
      issues.add('Internal control token visible in reply');
      score -= 0.2;
    }

    final relevant = assistantReply.length > 5;
    final uncertaintyHandled = assistantReply.toLowerCase().contains('uncertain') ||
        assistantReply.toLowerCase().contains('not sure') ||
        assistantReply.toLowerCase().contains('fallback') ||
        assistantReply.toLowerCase().contains('may') ||
        score > 0.5;

    score = score.clamp(0.0, 1.0);
    return EvaluationResult(
      score: score,
      factualConsistencyOk: !issues.any((i) => i.contains('consciousness')),
      relevant: relevant,
      uncertaintyHandled: uncertaintyHandled,
      issues: issues,
      summary: issues.isEmpty
          ? 'Heuristic check passed (not a guarantee of correctness).'
          : 'Issues: ${issues.join('; ')}',
    );
  }
}
