import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_mediapipe/flutter_edge_ai_mediapipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/engines/inference_engine.dart';
import '../../domain/models/model_info.dart';
import 'inference_diagnostics.dart';
import 'response_sanitizer.dart';
import 'stub_inference_engine.dart';

/// On-device Gemma via Flutter Edge AI (MediaPipe .task).
///
/// Generation strategy (evidence-based from package examples):
/// 1. **Primary:** [InferenceModel.createSession] + [InferenceModelSession.getResponse]
///    — this is the path shown in the flutter_edge_ai_mediapipe / flutter_gemma_mediapipe
///    README for .task models and returns a [String] directly.
/// 2. **Secondary:** [InferenceChat] streaming via generateChatResponseAsync.
///
/// MediaPipe prepends systemInstruction into the first user turn; we avoid
/// long systemInstruction text to prevent instruction-echo on 270M.
class GemmaInferenceEngine implements InferenceEngine {
  static const _prefsInstalledKey = 'evo_model_installed_id';
  static const int _contextTokens = 1024;

  final StubInferenceEngine _fallback = StubInferenceEngine();
  final _stateController = StreamController<ModelRuntimeState>.broadcast();
  final InferenceDiagnostics _diagnostics = InferenceDiagnostics();

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
  InferenceDiagnostics get diagnostics => _diagnostics;

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
    _diagnostics.add(msg);
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
      _log('init: MediaPipeEngine ok');
    } catch (e, st) {
      _log('init FAIL: $e');
      debugPrint('$st');
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
    _log('init: prefsInstalled=$installed modelId=${_spec.id}');
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
      _log('install: complete');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsInstalledKey, _spec.id);

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
      _log('install FAIL: $e');
      debugPrint('$st');
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
      // Gemma 3 270M GPU on Android is WIP (HF litert-community note).
      // Other models have returned empty/pad-only output on GPU while CPU works.
      // Force CPU so generation is not a silent empty string on mid-range phones.
      _model = await FlutterEdgeAi.getActiveModel(
        maxTokens: _contextTokens,
        preferredBackend: PreferredBackend.cpu,
      );
      String backendInfo = 'cpu';
      try {
        final dynamic ab = (_model as dynamic).activeBackend;
        backendInfo = ab?.toString() ?? 'cpu';
      } catch (_) {}
      _log(
        'load: getActiveModel ok type=${_model.runtimeType} '
        'contextTokens=$_contextTokens backend=$backendInfo',
      );
      _emit(_state.copyWith(
        phase: ModelPhase.ready,
        message: 'Gemma 3 270M ready (on-device).',
        usingFallback: false,
        error: null,
      ));
    } catch (e, st) {
      _log('load FAIL: $e');
      debugPrint('$st');
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

    if (_model == null) {
      _lastGenerateWasGemma = false;
      _log('generate: no model handle — stub');
      final stub = await _fallback.generate(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        maxTokens: maxTokens,
      );
      return '⚠️ Fallback (Gemma model not loaded)\n\n$stub';
    }

    _generating = true;
    final userPayload = _buildUserPayload(systemPrompt, userMessage);
    _log(
      'generate start userChars=${userMessage.trim().length} '
      'payloadChars=${userPayload.length} model=${_model.runtimeType}',
    );

    try {
      // --- Path A: createSession + getResponse (official MediaPipe example) ---
      final sessionResult = await _generateViaSession(userPayload);
      if (sessionResult != null && sessionResult.trim().isNotEmpty) {
        return _finishOk(sessionResult, systemPrompt, path: 'session');
      }
      _log('pathA session empty or null');

      // --- Path B: createChat + stream (secondary) ---
      final chatResult = await _generateViaChat(userPayload);
      if (chatResult != null && chatResult.trim().isNotEmpty) {
        return _finishOk(chatResult, systemPrompt, path: 'chat-stream');
      }
      _log('pathB chat-stream empty or null');

      // --- Path C: bare user text via session once more ---
      final bare = userMessage.trim();
      if (bare != userPayload) {
        final bareResult = await _generateViaSession(bare);
        if (bareResult != null && bareResult.trim().isNotEmpty) {
          return _finishOk(bareResult, systemPrompt, path: 'session-bare');
        }
        _log('pathC session-bare empty or null');
      }

      // Last resort: drop handle and reload explicitly on CPU, one more session.
      _log('reload: forcing PreferredBackend.cpu after empty generation');
      try {
        await _model?.close();
      } catch (_) {}
      _model = null;
      _model = await FlutterEdgeAi.getActiveModel(
        maxTokens: _contextTokens,
        preferredBackend: PreferredBackend.cpu,
      );
      final retry = await _generateViaSession(userMessage.trim());
      if (retry != null && retry.trim().isNotEmpty) {
        return _finishOk(retry, systemPrompt, path: 'session-cpu-reload');
      }
      _log('reload session still empty chars=${retry?.length ?? 0}');

      _lastGenerateWasGemma = false;
      final diagTail = _diagnostics.lines.length > 12
          ? _diagnostics.lines.sublist(_diagnostics.lines.length - 12).join('\n')
          : _diagnostics.asText;
      return 'On-device model returned an empty reply on this device.\n\n'
          'Native getResponse returned String with 0 characters (not an app extraction bug). '
          'Gemma 3 270M GPU on Android is WIP — this build forces CPU.\n\n'
          'Open Settings → Inference diagnostics and share that text.\n\n'
          'Recent diagnostics:\n$diagTail';
    } catch (e, st) {
      _log('generate EXCEPTION: ${e.runtimeType}: $e');
      debugPrint('$st');
      _lastGenerateWasGemma = false;
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

  Future<String?> _generateViaSession(String userPayload) async {
    InferenceModelSession? session;
    try {
      _log('session: createSession…');
      // Prefer conservative sampling; omit topP (optional) — some MediaPipe
      // builds are sensitive. topK default in plugin is 1 (greedy).
      session = await _model!.createSession(
        temperature: 0.8,
        topK: 40,
      );
      _log('session: created ${session.runtimeType}');

      await session.addQueryChunk(
        Message.text(text: userPayload, isUser: true),
      );
      _log('session: addQueryChunk ok isUser=true');

      final reply = await session.getResponse();
      final text = _coerceToString(reply);
      _log('session: getResponse type=${reply.runtimeType} chars=${text.length}');
      return text;
    } catch (e, st) {
      _log('session FAIL: ${e.runtimeType}: $e');
      debugPrint('$st');
      return null;
    } finally {
      try {
        await session?.close();
      } catch (e) {
        _log('session.close: $e');
      }
    }
  }

  Future<String?> _generateViaChat(String userPayload) async {
    InferenceChat? chat;
    try {
      _log('chat: createChat modelType=gemmaIt…');
      chat = await _model!.createChat(
        modelType: ModelType.gemmaIt,
        temperature: 0.8,
        topK: 40,
        maxOutputTokens: 256,
      );
      _log('chat: created ${chat.runtimeType}');

      await chat.addQueryChunk(
        Message.text(text: userPayload, isUser: true),
      );
      _log('chat: addQueryChunk ok');

      final buffer = StringBuffer();
      var events = 0;
      var textEvents = 0;
      await for (final chunk in chat.generateChatResponseAsync()) {
        events++;
        final piece = _extractText(chunk);
        if (piece.isNotEmpty) {
          textEvents++;
          buffer.write(piece);
        } else {
          _log('chat: empty chunk type=${chunk.runtimeType}');
        }
      }
      _log(
        'chat: stream done events=$events textEvents=$textEvents '
        'chars=${buffer.length}',
      );

      if (buffer.isNotEmpty) return buffer.toString();

      // Only if stream produced nothing — try sync once on a NEW chat.
      await chat.close();
      chat = null;
      chat = await _model!.createChat(
        modelType: ModelType.gemmaIt,
        temperature: 0.8,
        topK: 40,
        maxOutputTokens: 256,
      );
      await chat.addQueryChunk(
        Message.text(text: userPayload, isUser: true),
      );
      final response = await chat.generateChatResponse();
      final text = _extractText(response);
      _log('chat: sync type=${response.runtimeType} chars=${text.length}');
      return text;
    } catch (e, st) {
      _log('chat FAIL: ${e.runtimeType}: $e');
      debugPrint('$st');
      return null;
    } finally {
      try {
        await chat?.close();
      } catch (e) {
        _log('chat.close: $e');
      }
    }
  }

  String _finishOk(String raw, String systemPrompt, {required String path}) {
    final result = ResponseSanitizer.process(raw, systemPrompt: systemPrompt);
    if (!result.ok) {
      _log('sanitizer REJECT path=$path inChars=${raw.length}');
      _lastGenerateWasGemma = false;
      return result.text;
    }
    _lastGenerateWasGemma = true;
    _log('generate OK path=$path outChars=${result.text.length}');
    return result.text;
  }

  String _buildUserPayload(String systemPrompt, String userMessage) {
    final user = userMessage.trim();
    final memory = _extractMemoryLines(systemPrompt);
    if (memory == null || memory.isEmpty) return user;
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

  String _coerceToString(dynamic reply) {
    if (reply == null) return '';
    if (reply is String) return reply;
    return _extractText(reply);
  }

  String _extractText(dynamic response) {
    if (response == null) return '';
    if (response is String) return response;
    if (response is TextResponse) return response.token;
    try {
      final dynamic t = response.token;
      if (t is String) return t;
      if (t != null) return t.toString();
    } catch (_) {}
    try {
      final dynamic t = response.text;
      if (t is String) return t;
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
