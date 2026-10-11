import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_mediapipe/flutter_edge_ai_mediapipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/engines/inference_engine.dart';
import '../../domain/models/model_info.dart';
import 'response_sanitizer.dart';
import 'stub_inference_engine.dart';

/// On-device Gemma via Flutter Edge AI (MediaPipe .task path).
///
/// Critical MediaPipe behavior (from flutter_edge_ai docs):
///   ".litertlm … passed as a real system turn.
///    MediaPipe .task … systemInstruction is **prepended to the first user
///    message as a fallback**."
///
/// On Gemma 3 270M that prepend causes the model to *continue* the instruction
/// text instead of answering. Therefore this engine does **not** pass a long
/// systemInstruction to createChat for the MediaPipe path. Context is folded
/// lightly into the user turn only when needed (memory), and output is
/// validated by [ResponseSanitizer].
class GemmaInferenceEngine implements InferenceEngine {
  static const _prefsInstalledKey = 'evo_model_installed_id';
  static const int _contextTokens = 1024;

  final StubInferenceEngine _fallback = StubInferenceEngine();
  final _stateController = StreamController<ModelRuntimeState>.broadcast();

  ModelRuntimeState _state = const ModelRuntimeState(
    phase: ModelPhase.notInstalled,
    message: 'No on-device model loaded — using fallback responder.',
    usingFallback: true,
  );

  InferenceModel? _model;
  bool _pluginReady = false;
  bool _lastGenerateWasGemma = false;
  bool _loading = false;
  bool _generating = false;
  final OnDeviceModelSpec _spec = ModelCatalog.defaultModel;

  @override
  String get name =>
      (_model != null && !_state.usingFallback)
          ? 'Gemma 3 270M (on-device)'
          : 'Fallback (Gemma not ready)';

  @override
  bool get isReady => true;

  @override
  String? get statusMessage => _state.message ?? _state.error;

  @override
  bool get isUsingRealModel => _lastGenerateWasGemma;

  @override
  ModelRuntimeState get modelState => _state;

  @override
  Stream<ModelRuntimeState> get modelStateStream => _stateController.stream;

  void _emit(ModelRuntimeState s) {
    _state = s;
    if (!_stateController.isClosed) {
      _stateController.add(s);
    }
  }

  @override
  Future<void> initialize() async {
    await _fallback.initialize();
    try {
      await FlutterEdgeAi.initialize(
        inferenceEngines: const [MediaPipeEngine()],
      );
      _pluginReady = true;
    } catch (e, st) {
      debugPrint('FlutterEdgeAi.initialize failed: $e\n$st');
      _pluginReady = false;
      _emit(_state.copyWith(
        phase: ModelPhase.error,
        error: 'On-device runtime failed to initialize: $e',
        message: 'Using fallback responder.',
        usingFallback: true,
      ));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final installed = prefs.getString(_prefsInstalledKey) == _spec.id;
    if (installed) {
      _emit(_state.copyWith(
        phase: ModelPhase.loading,
        message: 'Model marked installed. Loading…',
        usingFallback: true,
      ));
      try {
        await ensureModelLoaded();
      } catch (e) {
        _emit(_state.copyWith(
          phase: ModelPhase.error,
          error: 'Installed model failed to load: $e',
          message: 'Using fallback. Try re-download in Settings.',
          usingFallback: true,
        ));
      }
    } else {
      _emit(_state.copyWith(
        phase: ModelPhase.notInstalled,
        message:
            'Download Gemma 3 270M (~${_spec.sizeLabel}) in Settings to enable real on-device replies.',
        usingFallback: true,
      ));
    }
  }

  @override
  Future<void> downloadAndInstallModel({String? huggingFaceToken}) async {
    if (!_pluginReady) {
      await initialize();
      if (!_pluginReady) {
        throw StateError('On-device plugin not available on this device');
      }
    }

    _emit(_state.copyWith(
      phase: ModelPhase.downloading,
      downloadProgress: 0,
      message: 'Downloading ${_spec.displayName}…',
      error: null,
      usingFallback: true,
    ));

    try {
      var installer = FlutterEdgeAi.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.task,
      ).fromNetwork(
        _spec.networkUrl,
        token: huggingFaceToken,
      );

      installer = installer.withProgress((progress) {
        final double p = progress.toDouble();
        final normalized =
            p > 1.0 ? (p / 100.0).clamp(0.0, 1.0) : p.clamp(0.0, 1.0);
        _emit(_state.copyWith(
          phase: ModelPhase.downloading,
          downloadProgress: normalized,
          message: 'Downloading… ${(normalized * 100).toStringAsFixed(0)}%',
        ));
      });

      _emit(_state.copyWith(
        phase: ModelPhase.installing,
        message: 'Installing model…',
      ));

      await installer.install();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsInstalledKey, _spec.id);

      _emit(_state.copyWith(
        phase: ModelPhase.ready,
        downloadProgress: 1,
        message: 'Model installed. Loading into memory…',
        error: null,
      ));

      await ensureModelLoaded();
    } catch (e, st) {
      debugPrint('Model download/install failed: $e\n$st');
      _emit(_state.copyWith(
        phase: ModelPhase.error,
        error: e.toString(),
        message:
            'Download failed. If the model is gated, accept Gemma terms on Hugging Face '
            '(litert-community/gemma-3-270m-it), paste an HF token in Settings, then retry.',
        usingFallback: true,
      ));
      rethrow;
    }
  }

  @override
  Future<void> ensureModelLoaded() async {
    if (_model != null) {
      _emit(_state.copyWith(
        phase: ModelPhase.ready,
        message: 'Gemma 3 270M ready (on-device).',
        usingFallback: false,
        error: null,
      ));
      return;
    }
    if (!_pluginReady) {
      throw StateError('Plugin not initialized');
    }
    if (_loading) return;
    _loading = true;

    _emit(_state.copyWith(
      phase: ModelPhase.loading,
      message: 'Loading model into memory…',
    ));

    try {
      _model = await FlutterEdgeAi.getActiveModel(maxTokens: _contextTokens);
      _emit(_state.copyWith(
        phase: ModelPhase.ready,
        message: 'Gemma 3 270M ready (on-device).',
        usingFallback: false,
        error: null,
      ));
    } catch (e, st) {
      debugPrint('getActiveModel failed: $e\n$st');
      _model = null;
      _emit(_state.copyWith(
        phase: ModelPhase.error,
        error: 'Could not load model: $e',
        message: 'Using fallback responder.',
        usingFallback: true,
      ));
      rethrow;
    } finally {
      _loading = false;
    }
  }

  @override
  Future<String> generate({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 512,
  }) async {
    if (_generating) {
      return 'Please wait for the current reply to finish.';
    }

    if (_model != null) {
      _generating = true;
      InferenceChat? chat;
      try {
        // MediaPipe prepends systemInstruction into the user turn. Long text
        // makes 270M continue the instructions. Use NO systemInstruction.
        chat = await _model!.createChat(
          temperature: 0.8,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: maxTokens.clamp(64, 256),
        );

        // Optional short memory/context folded into the user turn only when
        // present and not the placeholder "None."
        final userPayload = _buildUserPayload(systemPrompt, userMessage);

        await chat.addQueryChunk(
          Message.text(text: userPayload, isUser: true),
        );

        final response = await chat.generateChatResponse();
        final raw = _extractText(response);
        if (raw.trim().isEmpty) {
          throw StateError('Empty model response');
        }

        final result = ResponseSanitizer.process(
          raw,
          systemPrompt: systemPrompt,
        );
        if (!result.ok) {
          // Do not present instruction-echo as a successful answer.
          // One retry with the bare user message (no context prefix).
          debugPrint('Sanitize rejected first output: ${result.text}');
          try {
            await chat.close();
          } catch (_) {}
          chat = await _model!.createChat(
            temperature: 0.9,
            topK: 50,
            topP: 0.95,
            maxOutputTokens: maxTokens.clamp(64, 192),
          );
          await chat.addQueryChunk(
            Message.text(text: userMessage.trim(), isUser: true),
          );
          final response2 = await chat.generateChatResponse();
          final raw2 = _extractText(response2);
          final result2 = ResponseSanitizer.process(raw2);
          if (!result2.ok || raw2.trim().isEmpty) {
            _lastGenerateWasGemma = false;
            return 'On-device model could not produce a clean reply for that '
                'message (instruction echo). Try a fuller question.';
          }
          _lastGenerateWasGemma = true;
          return result2.text;
        }

        _lastGenerateWasGemma = true;
        return result.text;
      } catch (e, st) {
        debugPrint('Gemma generate failed, falling back: $e\n$st');
        _lastGenerateWasGemma = false;
        final stub = await _fallback.generate(
          systemPrompt: systemPrompt,
          userMessage: userMessage,
          maxTokens: maxTokens,
        );
        return '⚠️ Fallback (on-device model error: $e)\n\n$stub';
      } finally {
        _generating = false;
        try {
          await chat?.close();
        } catch (_) {}
      }
    }

    _lastGenerateWasGemma = false;
    final stub = await _fallback.generate(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      maxTokens: maxTokens,
    );
    return '⚠️ Fallback (Gemma model not loaded)\n\n$stub';
  }

  /// Builds the text sent as the single user Message.
  ///
  /// Memory is included only when non-empty. We never re-inject the full
  /// system prompt (that is what MediaPipe would prepend and the model echoes).
  String _buildUserPayload(String systemPrompt, String userMessage) {
    final user = userMessage.trim();
    final memory = _extractMemoryLines(systemPrompt);
    if (memory == null || memory.isEmpty) {
      return user;
    }
    // Short, natural framing — not "system instructions".
    return 'Useful facts from my notes:\n$memory\n\n$user';
  }

  String? _extractMemoryLines(String systemPrompt) {
    final marker = 'Relevant memory';
    final idx = systemPrompt.indexOf(marker);
    if (idx < 0) return null;
    final after = systemPrompt.substring(idx);
    final lines = after
        .split('\n')
        .skip(1)
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l != 'None.' && l != 'None')
        .where((l) => l.startsWith('-'))
        .take(3)
        .toList();
    if (lines.isEmpty) return null;
    return lines.join('\n');
  }

  String _extractText(dynamic response) {
    if (response == null) return '';
    if (response is String) return response;
    try {
      final dynamic t = response.token ?? response.text ?? response.message;
      if (t != null) return t.toString();
    } catch (_) {}
    final s = response.toString();
    if (s.startsWith('Instance of')) return '';
    return s;
  }

  @override
  Future<void> dispose() async {
    try {
      await _model?.close();
    } catch (_) {}
    _model = null;
    await _fallback.dispose();
    if (!_stateController.isClosed) {
      await _stateController.close();
    }
  }
}
