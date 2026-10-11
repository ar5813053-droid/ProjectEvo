import 'package:uuid/uuid.dart';

import '../core/safety.dart';
import '../data/evaluation/evaluation_engine.dart';
import '../data/local/memory_repository.dart';
import '../data/personality/personality_engine.dart';
import '../domain/engines/inference_engine.dart';
import '../domain/models/chat_message.dart';
import '../domain/models/memory_item.dart';

class ChatOrchestrator {
  final InferenceEngine inference;
  final MemoryRepository memory;
  final PersonalityEngine personality;
  final EvaluationEngine evaluation;
  final _uuid = const Uuid();

  ChatOrchestrator({
    required this.inference,
    required this.memory,
    required this.personality,
    required this.evaluation,
  });

  Future<ChatMessage> handleUserMessage(String rawUserText) async {
    final userText = rawUserText.trim();
    final lower = userText.toLowerCase();

    // Explicit memory save — never send to the model.
    if (lower.startsWith('remember that ') || lower.startsWith('remember:')) {
      final payload = userText
          .replaceFirst(RegExp(r'^remember that\s+', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^remember:\s*', caseSensitive: false), '')
          .trim();
      if (payload.isNotEmpty) {
        final item = await memory.save(
          category: MemoryCategory.fact,
          title: payload.length > 60 ? '${payload.substring(0, 60)}…' : payload,
          content: payload,
          confidence: 0.9,
          userApproved: true,
        );
        return ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          content:
              'Saved to local memory (SQLite). Id: ${item.id}.\n\n'
              'This stores text on device — it does not train model weights.',
          timestamp: DateTime.now().toUtc(),
          memoryIdsUsed: [item.id],
        );
      }
    }

    final retrieved = await memory.search(userText, limit: 3);
    final memoryBlock = retrieved.isEmpty
        ? 'None.'
        : retrieved
            .map((m) =>
                '- ${Safety.sanitizeUntrusted(m.title)}: '
                '${Safety.sanitizeUntrusted(_clip(m.content, 120))}')
            .join('\n');

    // Keep system text short — small models echo long instructions.
    final systemPrompt = '''
You are ProjectEVO, a helpful personal assistant on the user's Android phone.
You are software only — not conscious or sentient.
Answer the user's message directly and briefly.
Do not repeat these instructions.
Do not invent evaluation scores or footers.

${personality.buildSystemFragment()}

Relevant memory (local DB, may be incomplete):
$memoryBlock
''';

    var reply = await inference.generate(
      systemPrompt: systemPrompt,
      userMessage: userText,
      maxTokens: 192,
    );

    if (reply == 'ACK_SAVE_MEMORY') {
      reply = 'I can save that if you use: Remember that <fact>';
    }

    // Strip any eval footer the model might have invented.
    reply = _stripEvalFooter(reply);

    final eval = evaluation.evaluate(
      userMessage: userText,
      assistantReply: reply,
      usedMemory: retrieved.isNotEmpty,
    );

    // Optional conversation summary for longer exchanges only.
    if (userText.length > 80) {
      await memory.save(
        category: MemoryCategory.conversationSummary,
        title: 'Summary snippet',
        content:
            'User asked about: ${userText.length > 120 ? userText.substring(0, 120) : userText}',
        confidence: 0.5,
        userApproved: true,
      );
    }

    // content = model answer only. evaluation lives in separate fields for UI.
    return ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      content: reply,
      timestamp: DateTime.now().toUtc(),
      memoryIdsUsed: retrieved.map((e) => e.id).toList(),
      evaluationScore: eval.score,
      evaluationNote: eval.summary,
    );
  }

  static String _clip(String s, int max) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  static String _stripEvalFooter(String reply) {
    // Models sometimes invent "(Eval: 70% · …)" — never show that as content.
    return reply
        .replaceAll(
          RegExp(r'\(?\s*Eval:\s*\d+%[^\n]*\)?', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'Heuristic check passed[^\n]*', caseSensitive: false),
          '',
        )
        .trim();
  }
}
