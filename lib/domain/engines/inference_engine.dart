/// Replaceable AI inference backend. Implementations must never claim sentience.
abstract class InferenceEngine {
  String get name;
  bool get isReady;
  String? get statusMessage;

  Future<void> initialize();
  Future<void> dispose();

  /// Generate a completion. [systemPrompt] may include memory + personality.
  Future<String> generate({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 512,
  });
}
