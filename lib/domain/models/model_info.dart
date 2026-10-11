/// Catalog entry for an on-device model ProjectEVO can download.
class OnDeviceModelSpec {
  final String id;
  final String displayName;
  final String description;
  final String networkUrl;
  final String fileName;
  final int approximateBytes;
  final String licenseNote;
  final bool mayRequireHuggingFaceAccess;

  const OnDeviceModelSpec({
    required this.id,
    required this.displayName,
    required this.description,
    required this.networkUrl,
    required this.fileName,
    required this.approximateBytes,
    required this.licenseNote,
    this.mayRequireHuggingFaceAccess = true,
  });

  String get sizeLabel {
    final mb = approximateBytes / (1024 * 1024);
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(0)} MB';
  }
}

/// Models for mid-range phones (e.g. 6 GB RAM POCO X3 Pro).
///
/// Device evidence (POCO X3 Pro): Gemma 3 270M q8 .task loads and accepts
/// queries but native MediaPipe getResponse returns String with 0 characters
/// on both GPU and CPU. Google's MediaPipe LLM Inference guide primarily
/// documents Gemma-3 1B .task for Android generation.
class ModelCatalog {
  /// Gemma 3 1B IT int4 .task — MediaPipe LLM Inference primary recommendation.
  static const gemma3_1b = OnDeviceModelSpec(
    id: 'gemma3-1b-it-int4',
    displayName: 'Gemma 3 1B Instruct (int4)',
    description:
        'Recommended for MediaPipe on Android. ~500–700 MB. Stronger than 270M. '
        'Needs free storage and a HF token if gated. Prefer Wi‑Fi.',
    networkUrl:
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
    fileName: 'gemma3-1b-it-int4.task',
    approximateBytes: 550 * 1024 * 1024,
    licenseNote: 'Gemma Terms of Use — accept on Hugging Face if gated.',
    mayRequireHuggingFaceAccess: true,
  );

  /// Gemma 3 270M — loads on this device but produced empty native replies
  /// in ProjectEVO diagnostics; kept as optional fallback download.
  static const gemma3_270m = OnDeviceModelSpec(
    id: 'gemma3-270m-it-q8',
    displayName: 'Gemma 3 270M Instruct (q8)',
    description:
        'Smaller (~300 MB). Loaded on POCO X3 Pro but MediaPipe returned empty '
        'generation (0 tokens). Prefer Gemma 3 1B unless testing.',
    networkUrl:
        'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task',
    fileName: 'gemma3-270m-it-q8.task',
    approximateBytes: 300 * 1024 * 1024,
    licenseNote: 'Gemma Terms of Use — accept on Hugging Face if gated.',
    mayRequireHuggingFaceAccess: true,
  );

  static const List<OnDeviceModelSpec> all = [gemma3_1b, gemma3_270m];

  static OnDeviceModelSpec get defaultModel => gemma3_1b;

  static OnDeviceModelSpec byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return defaultModel;
  }
}

enum ModelPhase {
  notInstalled,
  downloading,
  installing,
  ready,
  loading,
  error,
}

class ModelRuntimeState {
  final ModelPhase phase;
  final double downloadProgress; // 0..1
  final String? message;
  final String? error;
  final bool usingFallback;
  final bool generatingWithGemma;

  const ModelRuntimeState({
    this.phase = ModelPhase.notInstalled,
    this.downloadProgress = 0,
    this.message,
    this.error,
    this.usingFallback = true,
    this.generatingWithGemma = false,
  });

  ModelRuntimeState copyWith({
    ModelPhase? phase,
    double? downloadProgress,
    String? message,
    String? error,
    bool? usingFallback,
    bool? generatingWithGemma,
  }) {
    return ModelRuntimeState(
      phase: phase ?? this.phase,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      message: message ?? this.message,
      error: error,
      usingFallback: usingFallback ?? this.usingFallback,
      generatingWithGemma: generatingWithGemma ?? this.generatingWithGemma,
    );
  }
}
