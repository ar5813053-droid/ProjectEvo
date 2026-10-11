import 'package:flutter_test/flutter_test.dart';
import 'package:project_evo/data/inference/stub_inference_engine.dart';

void main() {
  test('stub answers identity without claiming consciousness', () async {
    final e = StubInferenceEngine();
    await e.initialize();
    final r = await e.generate(
      systemPrompt: 'test',
      userMessage: 'Who are you?',
    );
    expect(r.contains('ProjectEVO'), isTrue);
    expect(r.toLowerCase().contains('i am conscious'), isFalse);
    expect(r.toLowerCase().contains('i have feelings'), isFalse);
  });
}
