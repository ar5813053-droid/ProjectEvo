import '../models/model_info.dart';
import '../../data/inference/inference_diagnostics.dart';

/// Replaceable AI inference backend. Implementations must never claim sentience.
abstract class InferenceEngine {
  String get name;
  bool get isReady;
  String? get statusMessage;

  /// Whether the last successful generate used the real Gemma runtime.
  bool get isUsingRealModel;

  ModelRuntimeState get modelState;

  Stream<ModelRuntimeState> get modelStateStream;

  /// Safe on-device diagnostics (no secrets / memory / full prompts).
  InferenceDiagnostics get diagnostics;

  Future<void> initialize();
  Future<void> dispose();

  /// Download + install the preferred on-device model (if not present).
  Future<void> downloadAndInstallModel({String? huggingFaceToken});

  /// Load model into memory for generation (idempotent).
  Future<void> ensureModelLoaded();

  /// Optional: switch preferred catalog model (requires re-download).
  Future<void> selectModel(OnDeviceModelSpec spec) async {}

  OnDeviceModelSpec get selectedModelSpec;

  /// Generate a completion. [systemPrompt] may include memory + personality.
  Future<String> generate({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 512,
  });
}
