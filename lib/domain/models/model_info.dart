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

/// Recommended models for mid-range phones (e.g. 6 GB RAM POCO X3 Pro).
class ModelCatalog {
  /// Gemma 3 270M IT — smallest official Gemma instruct variant for on-device.
  /// Format: MediaPipe .task (q8). ~300 MB download.
  /// Host: litert-community (may require accepting Gemma terms on Hugging Face).
  static const gemma3_270m = OnDeviceModelSpec(
    id: 'gemma3-270m-it-q8',
    displayName: 'Gemma 3 270M Instruct',
    description:
        'Small instruction-tuned Gemma 3 (~270M params). Best first choice for 6 GB phones. '
        'Not as capable as 1B/E2B models, but far more likely to load without OOM.',
    networkUrl:
        'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task',
    fileName: 'gemma3-270m-it-q8.task',
    approximateBytes: 300 * 1024 * 1024,
    licenseNote: 'Gemma Terms of Use — accept on Hugging Face if gated.',
    mayRequireHuggingFaceAccess: true,
  );

  static const List<OnDeviceModelSpec> all = [gemma3_270m];

  static OnDeviceModelSpec get defaultModel => gemma3_270m;
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
