/// Persistent memory entry. This is stored data, not model-weight training.
enum MemoryCategory {
  preference,
  fact,
  conversationSummary,
  researchKnowledge,
  projectGoal,
  correction,
  systemSetting,
}

class MemoryItem {
  final String id;
  final MemoryCategory category;
  final String title;
  final String content;
  final String? sourceUrl;
  final String? sourceTitle;
  final double confidence;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool userApproved;
  final DateTime? expiresAt;

  const MemoryItem({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    this.sourceUrl,
    this.sourceTitle,
    this.confidence = 0.7,
    required this.createdAt,
    required this.updatedAt,
    this.userApproved = true,
    this.expiresAt,
  });

  MemoryItem copyWith({
    String? title,
    String? content,
    double? confidence,
    bool? userApproved,
    DateTime? updatedAt,
    DateTime? expiresAt,
  }) {
    return MemoryItem(
      id: id,
      category: category,
      title: title ?? this.title,
      content: content ?? this.content,
      sourceUrl: sourceUrl,
      sourceTitle: sourceTitle,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userApproved: userApproved ?? this.userApproved,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category.name,
        'title': title,
        'content': content,
        'source_url': sourceUrl,
        'source_title': sourceTitle,
        'confidence': confidence,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'user_approved': userApproved ? 1 : 0,
        'expires_at': expiresAt?.toIso8601String(),
      };

  factory MemoryItem.fromMap(Map<String, dynamic> m) => MemoryItem(
        id: m['id'] as String,
        category: MemoryCategory.values.firstWhere(
          (e) => e.name == m['category'],
          orElse: () => MemoryCategory.fact,
        ),
        title: m['title'] as String,
        content: m['content'] as String,
        sourceUrl: m['source_url'] as String?,
        sourceTitle: m['source_title'] as String?,
        confidence: (m['confidence'] as num?)?.toDouble() ?? 0.7,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        userApproved: (m['user_approved'] as int? ?? 1) == 1,
        expiresAt: m['expires_at'] != null
            ? DateTime.tryParse(m['expires_at'] as String)
            : null,
      );
}
