import 'package:flutter_test/flutter_test.dart';
import 'package:project_evo/data/inference/stub_inference_engine.dart';
import 'package:project_evo/domain/models/model_info.dart';

void main() {
  group('StubInferenceEngine', () {
    late StubInferenceEngine engine;

    setUp(() async {
      engine = StubInferenceEngine();
      await engine.initialize();
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('is ready after initialize', () {
      expect(engine.isReady, isTrue);
      expect(engine.name.toLowerCase(), contains('stub'));
    });

    test('answers identity without claiming consciousness', () async {
      final r = await engine.generate(
        systemPrompt: 'test',
        userMessage: 'Who are you?',
      );
      expect(r.contains('ProjectEVO'), isTrue);
      expect(r.toLowerCase().contains('i am conscious'), isFalse);
      expect(r.toLowerCase().contains('i have feelings'), isFalse);
    });

    test('returns ACK_SAVE_MEMORY for remember commands', () async {
      final r = await engine.generate(
        systemPrompt: 'test',
        userMessage: 'Remember that my name is Alex',
      );
      expect(r, equals('ACK_SAVE_MEMORY'));
    });

    test('labels fallback in generic replies', () async {
      final r = await engine.generate(
        systemPrompt: 'Relevant memory here',
        userMessage: 'What is the capital of France?',
      );
      expect(r.toLowerCase(), contains('fallback'));
    });
  });

  group('ModelCatalog', () {
    test('default model is Gemma 3 1B', () {
      final m = ModelCatalog.defaultModel;
      expect(m.id, contains('1b'));
      expect(m.networkUrl, contains('huggingface.co'));
      expect(m.networkUrl, contains('.task'));
      expect(m.approximateBytes, greaterThan(100 * 1024 * 1024));
      expect(m.sizeLabel, contains('MB'));
    });

    test('ModelRuntimeState copyWith preserves fields', () {
      const s = ModelRuntimeState(
        phase: ModelPhase.downloading,
        downloadProgress: 0.4,
        message: 'mid',
        usingFallback: true,
      );
      final s2 = s.copyWith(phase: ModelPhase.ready, usingFallback: false);
      expect(s2.phase, ModelPhase.ready);
      expect(s2.downloadProgress, 0.4);
      expect(s2.usingFallback, isFalse);
      expect(s2.message, 'mid');
    });
  });
}
