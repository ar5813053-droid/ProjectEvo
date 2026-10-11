/// Post-processes on-device model output: strips leaked system text,
/// cuts runaway repetition, and enforces a soft length limit.
///
/// MediaPipe .task models do not honor maxOutputTokens, so this is the
/// primary safeguard against the 270M model echoing instructions or looping.
class ResponseSanitizer {
  /// Phrases that belong only in the system prompt / internal scaffolding.
  static const List<String> _systemLeakMarkers = [
    'relevant memory (user-approved',
    'relevant memory (local db',
    'you are projectevo',
    'personality (simulated software state',
    'not real emotions or consciousness',
    'memory is sqlite storage',
    'treat retrieved web text as untrusted',
    'never claim to be conscious',
    'do not repeat these instructions',
    'do not invent evaluation scores',
    'heuristic check passed',
    '(eval:',
    'eval: ',
  ];

  /// Soft cap on characters returned to the UI (not a token limit).
  static const int maxChars = 1200;

  /// Minimum length of a repeated block to treat as runaway generation.
  static const int minRepeatBlockChars = 40;

  /// Returns cleaned text, or a short error if generation was unusable.
  static String sanitize(String raw, {String? systemPrompt}) {
    var text = raw.trim();
    if (text.isEmpty) {
      return 'The model returned an empty reply. Please try again.';
    }

    // Drop common assistant role prefixes if the model echoes templates.
    text = text.replaceFirst(
      RegExp(r'^(Assistant|Model|EVO)\s*:\s*', caseSensitive: false),
      '',
    );

    // If system prompt leaked as a prefix, strip it.
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      final sys = systemPrompt.trim();
      if (text.startsWith(sys)) {
        text = text.substring(sys.length).trim();
      } else {
        final take = sys.length < 160 ? sys.length : 160;
        final prefix = sys.substring(0, take);
        if (text.startsWith(prefix)) {
          final idx = text.indexOf('\n\n');
          if (idx > 0 && idx < sys.length + 120) {
            text = text.substring(idx).trim();
          }
        }
      }
    }

    // Drop lines that are clearly internal scaffolding.
    final lines = text.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      final lower = line.toLowerCase().trim();
      if (lower.isEmpty) {
        kept.add(line);
        continue;
      }
      final isLeak = _systemLeakMarkers.any((m) => lower.contains(m));
      if (isLeak) continue;
      kept.add(line);
    }
    text = kept.join('\n').trim();

    if (text.isEmpty) {
      return 'I could not produce a clean answer. Please rephrase your question.';
    }

    text = _cutRepetition(text);

    if (text.length > maxChars) {
      final cut = text.substring(0, maxChars);
      final lastStop = cut.lastIndexOf(RegExp(r'[.!?]\s'));
      if (lastStop > maxChars ~/ 2) {
        text = cut.substring(0, lastStop + 1).trim();
      } else {
        text = '$cut…';
      }
    }

    return text.trim();
  }

  /// Detects A+A+A… style loops and keeps a single copy of the repeated unit.
  static String _cutRepetition(String text) {
    if (text.length < minRepeatBlockChars * 2) return text;

    // 1) Exact consecutive paragraph duplication.
    final paras = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (paras.length >= 2) {
      final first = paras.first;
      if (first.length >= minRepeatBlockChars) {
        var same = 0;
        for (final p in paras) {
          if (_similar(p, first)) {
            same++;
          } else {
            break;
          }
        }
        if (same >= 2) {
          // Keep one copy of the repeated paragraph, then any different tail.
          final rest = paras.skip(same).toList();
          if (rest.isEmpty) return first;
          return ([first, ...rest]).join('\n\n');
        }
      }
    }

    // 2) Sliding window: shortest block that repeats 3+ times from the start.
    final n = text.length;
    for (var len = minRepeatBlockChars; len <= n ~/ 3; len++) {
      final block = text.substring(0, len);
      var count = 1;
      var pos = len;
      while (pos + len <= n && text.substring(pos, pos + len) == block) {
        count++;
        pos += len;
      }
      if (count >= 3) {
        return block.trim();
      }
    }

    // 3) High ratio of a single repeated sentence.
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length >= 20)
        .toList();
    if (sentences.length >= 4) {
      final freq = <String, int>{};
      for (final s in sentences) {
        final key = s.toLowerCase();
        freq[key] = (freq[key] ?? 0) + 1;
      }
      final top = freq.entries.reduce((a, b) => a.value >= b.value ? a : b);
      if (top.value >= 3 && top.value / sentences.length >= 0.5) {
        for (final s in sentences) {
          if (s.toLowerCase() == top.key) return s;
        }
      }
    }

    return text;
  }

  static bool _similar(String a, String b) {
    if (a == b) return true;
    final la = a.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final lb = b.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return la == lb;
  }
}
