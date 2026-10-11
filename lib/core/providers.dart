import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/evaluation/evaluation_engine.dart';
import '../data/inference/gemma_inference_engine.dart';
import '../data/local/memory_repository.dart';
import '../data/personality/personality_engine.dart';
import '../data/research/research_service.dart';
import '../domain/engines/inference_engine.dart';
import '../domain/models/chat_message.dart';
import '../domain/models/personality_state.dart';
import '../services/chat_orchestrator.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository();
});

final inferenceEngineProvider = Provider<InferenceEngine>((ref) {
  return GemmaInferenceEngine();
});

final personalityEngineProvider = Provider<PersonalityEngine>((ref) {
  return PersonalityEngine();
});

final evaluationEngineProvider = Provider<EvaluationEngine>((ref) {
  return EvaluationEngine();
});

final researchServiceProvider = Provider<ResearchService>((ref) {
  return DuckDuckGoResearchService();
});

final chatOrchestratorProvider = Provider<ChatOrchestrator>((ref) {
  return ChatOrchestrator(
    inference: ref.watch(inferenceEngineProvider),
    memory: ref.watch(memoryRepositoryProvider),
    personality: ref.watch(personalityEngineProvider),
    evaluation: ref.watch(evaluationEngineProvider),
  );
});

final inferenceReadyProvider = FutureProvider<void>((ref) async {
  await ref.watch(inferenceEngineProvider).initialize();
});

class ChatState {
  final List<ChatMessage> messages;
  final bool busy;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.busy = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? busy,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      busy: busy ?? this.busy,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._ref) : super(const ChatState());

  final Ref _ref;

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;

    final userMsg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: trimmed,
      timestamp: DateTime.now().toUtc(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      busy: true,
      error: null,
    );

    try {
      final orch = _ref.read(chatOrchestratorProvider);
      final reply = await orch.handleUserMessage(trimmed);
      state = state.copyWith(
        messages: [...state.messages, reply],
        busy: false,
      );
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  void clear() => state = const ChatState();
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});

final personalityProvider =
    StateNotifierProvider<PersonalityNotifier, PersonalityConfig>((ref) {
  return PersonalityNotifier(ref);
});

class PersonalityNotifier extends StateNotifier<PersonalityConfig> {
  PersonalityNotifier(this._ref) : super(const PersonalityConfig());
  final Ref _ref;

  void update(PersonalityConfig c) {
    state = c;
    _ref.read(personalityEngineProvider).update(c);
  }
}
