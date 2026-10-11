enum ChatRole { user, assistant, system }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final List<String> memoryIdsUsed;
  final double? evaluationScore;
  final String? evaluationNote;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.memoryIdsUsed = const [],
    this.evaluationScore,
    this.evaluationNote,
  });
}
