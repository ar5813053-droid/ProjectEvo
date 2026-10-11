import '../../domain/engines/inference_engine.dart';
import 'stub_inference_engine.dart';

/// Placeholder for a future on-device Gemma / LiteRT-LM backend.
/// Does not download models or claim inference works without a verified runtime.
class GemmaInferenceEngine implements InferenceEngine {
  final StubInferenceEngine _fallback = StubInferenceEngine();
  bool _attempted = false;
  String _message = 'Gemma runtime not configured';

  @override
  String get name => 'Gemma (pending runtime)';

  @override
  bool get isReady => _fallback.isReady;

  @override
  String? get statusMessage => _message;

  @override
  Future<void> initialize() async {
    _attempted = true;
    // Real integration would load native libs + quantized weights here.
    // On a 6 GB device, only a carefully chosen small model may work.
    _message =
        'No compatible on-device Gemma runtime/model is bundled. Using safe fallback. '
        'See docs/MODELS.md for how to add a verified model later.';
    await _fallback.initialize();
  }

  @override
  Future<void> dispose() => _fallback.dispose();

  @override
  Future<String> generate({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 512,
  }) async {
    if (!_attempted) await initialize();
    return _fallback.generate(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      maxTokens: maxTokens,
    );
  }
}
