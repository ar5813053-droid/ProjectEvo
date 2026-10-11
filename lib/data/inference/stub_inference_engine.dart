import 'dart:async';

import '../../domain/engines/inference_engine.dart';
import '../../domain/models/model_info.dart';

/// Honest offline backend when no on-device Gemma runtime/model is configured.
class StubInferenceEngine implements InferenceEngine {
  bool _ready = false;
  final _stateController = StreamController<ModelRuntimeState>.broadcast();

  ModelRuntimeState _state = const ModelRuntimeState(
    phase: ModelPhase.notInstalled,
    message: 'Using rule-based fallback. Install a compatible on-device model for full chat.',
    usingFallback: true,
  );

  @override
  String get name => 'Stub (no local model loaded)';

  @override
  bool get isReady => _ready;

  @override
  String? get statusMessage => _state.message;

  @override
  bool get isUsingRealModel => false;

  @override
  ModelRuntimeState get modelState => _state;

  @override
  Stream<ModelRuntimeState> get modelStateStream => _stateController.stream;

  @override
  Future<void> initialize() async {
    _ready = true;
    _state = const ModelRuntimeState(
      phase: ModelPhase.notInstalled,
      message:
          'Using rule-based fallback. Install a compatible on-device model for full chat.',
      usingFallback: true,
    );
    if (!_stateController.isClosed) _stateController.add(_state);
  }

  @override
  Future<void> dispose() async {
    _ready = false;
    if (!_stateController.isClosed) await _stateController.close();
  }

  @override
  Future<void> downloadAndInstallModel({String? huggingFaceToken}) async {
    throw UnsupportedError(
      'Stub engine cannot download models. Use GemmaInferenceEngine.',
    );
  }

  @override
  Future<void> ensureModelLoaded() async {
    // no-op for stub
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
    if (lower.contains('who are you') || lower.contains('what are you')) {
      return 'I am ProjectEVO, a personal assistant app on your Android device. '
          'I use stored memory and optional research to help you. '
          'I am software — not conscious or sentient. '
          'A full on-device language model is not loaded yet; this is the built-in fallback responder.';
    }
    if (lower.startsWith('remember that ') || lower.startsWith('remember:')) {
      return 'ACK_SAVE_MEMORY'; // orchestrator intercepts
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
        'Next steps: download Gemma 3 270M in Settings → Model, '
        'or continue using Memory + Research modules. '
        'Simulated personality settings only affect tone scaffolding, not real emotions.';
  }
}
