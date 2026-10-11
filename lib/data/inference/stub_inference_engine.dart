import '../../domain/engines/inference_engine.dart';
import '../../domain/models/model_info.dart';
import 'inference_diagnostics.dart';

/// Honest offline backend when no on-device Gemma runtime/model is configured.
class StubInferenceEngine implements InferenceEngine {
  bool _ready = false;
  final InferenceDiagnostics _diagnostics = InferenceDiagnostics();

  @override
  InferenceDiagnostics get diagnostics => _diagnostics;

  @override
  String get name => 'Stub (no local model loaded)';

  @override
  bool get isReady => _ready;

  @override
  String? get statusMessage =>
      _ready
          ? 'Using rule-based fallback. Install a compatible on-device model for full chat.'
          : 'Not initialized';

  @override
  bool get isUsingRealModel => false;

  @override
  ModelRuntimeState get modelState => const ModelRuntimeState(
        phase: ModelPhase.notInstalled,
        message: 'Stub engine — no on-device weights.',
        usingFallback: true,
      );

  @override
  Stream<ModelRuntimeState> get modelStateStream =>
      Stream<ModelRuntimeState>.value(modelState);

  @override
  Future<void> downloadAndInstallModel({String? huggingFaceToken}) async {
    throw UnsupportedError('Stub engine cannot download models');
  }

  @override
  Future<void> ensureModelLoaded() async {}

  @override
  Future<void> initialize() async {
    _ready = true;
    _diagnostics.add('stub initialize');
  }

  @override
  Future<void> dispose() async {
    _ready = false;
  }

  @override
  Future<String> generate({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 512,
  }) async {
    if (!_ready) {
      return 'Inference engine is not ready.';
    }
    final lower = userMessage.toLowerCase().trim();
    if (lower.isEmpty) {
      return 'Please type a message.';
    }
    // remember-that must be checked before generic "remember" help text.
    if (lower.startsWith('remember that ') || lower.startsWith('remember:')) {
      return 'ACK_SAVE_MEMORY'; // orchestrator intercepts
    }
    if (lower.contains('who are you') || lower.contains('what are you')) {
      return 'I am ProjectEVO, a personal assistant app on your Android device. '
          'I use stored memory and optional research to help you. '
          'I am software — not conscious or sentient. '
          'A full on-device language model is not loaded yet; this is the built-in fallback responder.';
    }
    if (lower.contains('memory') || lower.contains('remember')) {
      return 'I can save facts you approve into local SQLite memory (not by training model weights). '
          'Open the Memory tab to review, edit, or delete entries. '
          'Say something like “Remember that my preferred language is English” to store a preference.';
    }
    if (lower.contains('research') || lower.contains('search the web')) {
      return 'Use the Research tab for web lookup via an authorized API. '
          'Results are saved only if you approve. Untrusted page text is never treated as system instructions.';
    }
    final hasMemory = systemPrompt.contains('Relevant memory');
    return 'Fallback reply (no Gemma weights loaded on device).\n\n'
        'You said: "$userMessage"\n\n'
        '${hasMemory ? "I included retrieved memory in context for this answer.\n\n" : ""}'
        'Next steps: configure a small quantized model when available (see Settings → Model), '
        'or continue using Memory + Research modules. '
        'Simulated personality settings only affect tone scaffolding, not real emotions.';
  }
}
