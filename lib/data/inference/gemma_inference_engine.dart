import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_mediapipe/flutter_edge_ai_mediapipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/engines/inference_engine.dart';
import '../../domain/models/model_info.dart';
import 'response_sanitizer.dart';
import 'stub_inference_engine.dart';

/// On-device Gemma via Flutter Edge AI (MediaPipe .task).
///
/// MediaPipe notes (flutter_edge_ai docs):
/// - systemInstruction is prepended into the first user turn (not a real
///   system role). We therefore avoid long systemInstruction text.
/// - generateChatResponse() returns ModelResponse (TextResponse.token).
/// - Official examples also stream via generateChatResponseAsync().
/// - Message.isUser must be true or the model returns empty.
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
  /// Long-lived chat session — create once after model load, reset on errors.
  InferenceChat? _chat;
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

  void _log(String msg) {
    debugPrint('[ProjectEVO/Gemma] $msg');
  }

  @override
  Future<void> initialize() async {
    await _fallback.initialize();
    try {
      await FlutterEdgeAi.initialize(
        inferenceEngines: const [MediaPipeEngine()],
      );
      _pluginReady = true;
      _log('FlutterEdgeAi initialized with MediaPipeEngine');
    } catch (e, st) {
      _log('FlutterEdgeAi.initialize failed: $e\n$st');
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

      // Drop any stale chat/model handles before reload.
      await _closeChat();
      try {
        await _model?.close();
      } catch (_) {}
      _model = null;

      _emit(_state.copyWith(
        phase: ModelPhase.ready,
        downloadProgress: 1,
        message: 'Model installed. Loading into memory…',
        error: null,
      ));

      await ensureModelLoaded();
    } catch (e, st) {
      _log('Model download/install failed: $e\n$st');
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
      _log('getActiveModel ok, maxTokens=$_contextTokens');
      // Open a chat session now so first user message is not racing init.
      await _ensureChat();
      _emit(_state.copyWith(
        phase: ModelPhase.ready,
        message: 'Gemma 3 270M ready (on-device).',
        usingFallback: false,
        error: null,
      ));
    } catch (e, st) {
      _log('getActiveModel failed: $e\n$st');
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

  Future<void> _ensureChat() async {
    if (_chat != null) return;
    if (_model == null) {
      throw StateError('Model not loaded');
    }
    // Explicit modelType so MediaPipe applies Gemma IT chat templates.
    _chat = await _model!.createChat(
      modelType: ModelType.gemmaIt,
      temperature: 0.8,
      topK: 40,
      topP: 0.95,
      // Context-window sibling; MediaPipe may ignore maxOutputTokens.
      maxOutputTokens: 256,
    );
    _log('createChat ok (modelType=gemmaIt)');
  }

  Future<void> _closeChat() async {
    final c = _chat;
    _chat = null;
    if (c == null) return;
    try {
      await c.close();
    } catch (e) {
      _log('chat.close error (ignored): $e');
    }
  }

  Future<void> _recreateChat() async {
    await _closeChat();
    await _ensureChat();
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

    if (_model == null) {
      _lastGenerateWasGemma = false;
      final stub = await _fallback.generate(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        maxTokens: maxTokens,
      );
      return '⚠️ Fallback (Gemma model not loaded)\n\n$stub';
    }

    _generating = true;
    try {
      await _ensureChat();
      final chat = _chat!;
      final userPayload = _buildUserPayload(systemPrompt, userMessage);
      _log(
        'generate start userLen=${userMessage.length} '
        'payloadLen=${userPayload.length}',
      );

      await chat.addQueryChunk(
        Message.text(text: userPayload, isUser: true),
      );

      // Prefer streaming accumulation — official examples use this path and
      // some MediaPipe builds return fuller text via the async stream.
      var raw = await _collectStreamedResponse(chat);
      _log('stream path chars=${raw.length}');

      // Fallback: sync generateChatResponse if stream was empty.
      if (raw.trim().isEmpty) {
        _log('stream empty — trying generateChatResponse()');
        final response = await chat.generateChatResponse();
        raw = _extractText(response);
        _log(
          'sync path type=${response.runtimeType} chars=${raw.length}',
        );
      }

      if (raw.trim().isEmpty) {
        // Session may be wedged — recreate once and retry with bare user text.
        _log('empty after both paths — recreate chat and retry once');
        await _recreateChat();
        final chat2 = _chat!;
        await chat2.addQueryChunk(
          Message.text(text: userMessage.trim(), isUser: true),
        );
        raw = await _collectStreamedResponse(chat2);
        if (raw.trim().isEmpty) {
          final response = await chat2.generateChatResponse();
          raw = _extractText(response);
        }
        _log('retry chars=${raw.length}');
      }

      if (raw.trim().isEmpty) {
        _lastGenerateWasGemma = false;
        // Do not pretend the model answered; keep diagnostics visible.
        return 'On-device model returned an empty reply. '
            'The model file may still be loading, or this device/runtime '
            'failed generation. Check logcat for [ProjectEVO/Gemma].';
      }

      final result = ResponseSanitizer.process(
        raw,
        systemPrompt: systemPrompt,
      );
      if (!result.ok) {
        _log('sanitizer rejected output (${raw.length} chars)');
        _lastGenerateWasGemma = false;
        return result.text; // clear error from sanitizer, not a fake answer
      }

      _lastGenerateWasGemma = true;
      _log('generate ok chars=${result.text.length}');
      return result.text;
    } catch (e, st) {
      _log('generate failed: $e\n$st');
      _lastGenerateWasGemma = false;
      // Recreate chat after hard failures so the next turn is clean.
      try {
        await _recreateChat();
      } catch (_) {}
      final stub = await _fallback.generate(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        maxTokens: maxTokens,
      );
      return '⚠️ Fallback (on-device model error: $e)\n\n$stub';
    } finally {
      _generating = false;
    }
  }

  /// Accumulate TextResponse tokens from the async stream.
  Future<String> _collectStreamedResponse(InferenceChat chat) async {
    final buffer = StringBuffer();
    try {
      await for (final chunk in chat.generateChatResponseAsync()) {
        final piece = _extractText(chunk);
        if (piece.isNotEmpty) {
          buffer.write(piece);
        }
      }
    } catch (e, st) {
      _log('generateChatResponseAsync error: $e\n$st');
      // Return whatever we have so far; caller may try sync path.
    }
    return buffer.toString();
  }

  String _buildUserPayload(String systemPrompt, String userMessage) {
    final user = userMessage.trim();
    final memory = _extractMemoryLines(systemPrompt);
    if (memory == null || memory.isEmpty) {
      return user;
    }
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

  /// Extract text from ModelResponse / TextResponse / String / dynamic.
  String _extractText(dynamic response) {
    if (response == null) return '';
    if (response is String) return response;

    // Preferred typed path.
    if (response is TextResponse) {
      return response.token;
    }

    // Dynamic fallbacks across package versions.
    try {
      final dynamic t = response.token;
      if (t is String && t.isNotEmpty) return t;
      if (t != null && t.toString().isNotEmpty) return t.toString();
    } catch (_) {}
    try {
      final dynamic t = response.text;
      if (t is String && t.isNotEmpty) return t;
      if (t != null && t.toString().isNotEmpty) return t.toString();
    } catch (_) {}
    try {
      final dynamic t = response.message;
      if (t is String && t.isNotEmpty) return t;
      if (t != null && t.toString().isNotEmpty) return t.toString();
    } catch (_) {}

    final s = response.toString();
    if (s.startsWith('Instance of')) return '';
    return s;
  }

  @override
  Future<void> dispose() async {
    await _closeChat();
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
