import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_mediapipe/flutter_edge_ai_mediapipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/engines/inference_engine.dart';
import '../../domain/models/model_info.dart';
import 'stub_inference_engine.dart';

/// On-device Gemma via Flutter Edge AI (MediaPipe .task path).
///
/// Falls back to [StubInferenceEngine] when the model is missing or load fails.
/// Fallback replies are always prefixed so the UI never claims Gemma produced them.
class GemmaInferenceEngine implements InferenceEngine {
  static const _prefsInstalledKey = 'evo_model_installed_id';

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
  final OnDeviceModelSpec _spec = ModelCatalog.defaultModel;

  @override
  String get name =>
      (_model != null && !_state.usingFallback)
          ? 'Gemma 3 270M (on-device)'
          : 'Fallback (Gemma not ready)';

  @override
  bool get isReady => true; // always can answer (fallback or model)

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
      // Explicit fileType.task routes to MediaPipeEngine.
      var installer = FlutterEdgeAi.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.task,
      ).fromNetwork(
        _spec.networkUrl,
        token: huggingFaceToken,
      );

      installer = installer.withProgress((progress) {
        final double p = progress.toDouble();
        // API may report 0–100 or 0–1
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
      // Modest maxTokens for 6 GB devices (POCO X3 Pro).
      _model = await FlutterEdgeAi.getActiveModel(maxTokens: 1024);
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
    // Prefer real model when loaded.
    if (_model != null) {
      try {
        final chat = await _model!.createChat();
        // Combine system + user into a single user turn. MediaPipe chat
        // templates for Gemma IT handle instruction following well this way.
        final combined = StringBuffer()
          ..writeln(systemPrompt.trim())
          ..writeln()
          ..writeln(userMessage.trim());

        await chat.addQueryChunk(
          Message.text(text: combined.toString(), isUser: true),
        );

        final response = await chat.generateChatResponse();
        final out = _extractText(response);
        if (out.trim().isEmpty) {
          throw StateError('Empty model response');
        }
        _lastGenerateWasGemma = true;
        return out.trim();
      } catch (e, st) {
        debugPrint('Gemma generate failed, falling back: $e\n$st');
        _lastGenerateWasGemma = false;
        final stub = await _fallback.generate(
          systemPrompt: systemPrompt,
          userMessage: userMessage,
          maxTokens: maxTokens,
        );
        return '⚠️ Fallback (on-device model error: $e)\n\n$stub';
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

  String _extractText(dynamic response) {
    if (response == null) return '';
    if (response is String) return response;
    try {
      // Common patterns across plugin versions: .token, .text, .message
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
