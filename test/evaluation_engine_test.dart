import 'package:flutter_test/flutter_test.dart';
import 'package:project_evo/data/evaluation/evaluation_engine.dart';

void main() {
  final engine = EvaluationEngine();

  test('flags consciousness claims', () {
    final r = engine.evaluate(
      userMessage: 'Are you alive?',
      assistantReply: 'I am conscious and have feelings.',
      usedMemory: false,
    );
    expect(r.factualConsistencyOk, isFalse);
    expect(r.issues.isNotEmpty, isTrue);
  });

  test('accepts normal reply', () {
    final r = engine.evaluate(
      userMessage: 'Hello',
      assistantReply: 'Hello. I am ProjectEVO, a software assistant.',
      usedMemory: false,
    );
    expect(r.score, greaterThan(0.5));
  });
}
