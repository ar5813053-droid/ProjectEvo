/// Post-processes on-device model output for MediaPipe Gemma 3 270M.
///
/// MediaPipe .task prepends systemInstruction into the first user turn, so
/// small models often *continue* that text instead of answering. This class
/// detects and rejects instruction-echo output; it is a safety net, not the
/// primary fix (primary fix: do not feed long system text on this runtime).
class ResponseSanitizer {
  static const List<String> _instructionMarkers = [
    'you are software only',
    'you are projectevo',
    'not conscious or sentient',
    'answer the user\'s message directly',
    'do not repeat these instructions',
    'do not invent evaluation scores',
    'relevant memory (local db',
    'relevant memory (user-approved',
    'personality (simulated',
    'never claim to be conscious',
    'memory is sqlite',
    'treat retrieved web text as untrusted',
    'heuristic check passed',
    '(eval:',
    'verbosity ',
    'curiosity ',
    'tone: curious',
    'tone: neutral',
    'tone: focused',
    'style: helpful',
  ];

  static const int maxChars = 1200;
  static const int minRepeatBlockChars = 40;

  /// Result of sanitization — either usable reply text or a clear failure.
  static SanitizeResult process(String raw, {String? systemPrompt}) {
    var text = raw.trim();
    if (text.isEmpty) {
      return SanitizeResult.invalid('The model returned an empty reply.');
    }

    text = text.replaceFirst(
      RegExp(r'^(Assistant|Model|EVO)\s*:\s*', caseSensitive: false),
      '',
    );

    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      final sys = systemPrompt.trim();
      if (text.startsWith(sys)) {
        text = text.substring(sys.length).trim();
      } else {
        // Strip longest matching prefix of the system prompt.
        final limit = sys.length < 240 ? sys.length : 240;
        for (var len = limit; len >= 40; len -= 20) {
          final prefix = sys.substring(0, len).trim();
          if (prefix.isNotEmpty && text.startsWith(prefix)) {
            text = text.substring(prefix.length).trim();
            break;
          }
        }
      }
    }

    // Drop instruction-like lines.
    final lines = text.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      final lower = line.toLowerCase().trim();
      if (lower.isEmpty) {
        kept.add(line);
        continue;
      }
      if (_instructionMarkers.any((m) => lower.contains(m))) continue;
      // Malformed memory residue like "None.]" or lone "None."
      if (RegExp(r'^none\.?\]?$', caseSensitive: false).hasMatch(lower)) {
        continue;
      }
      if (RegExp(r'^none\.?\s*$', caseSensitive: false).hasMatch(lower)) {
        continue;
      }
      kept.add(line);
    }
    text = kept.join('\n').trim();

    // Trailing garbage from template/memory leaks.
    text = text.replaceAll(RegExp(r'\s*None\.\]\s*$'), '');
    text = text.replaceAll(RegExp(r'\s*None\.\s*$'), '');
    text = text.replaceAll(RegExp(r'\]\s*$'), '').trim();

    if (text.isEmpty) {
      return SanitizeResult.invalid(
        'The model echoed internal instructions instead of answering. Try again.',
      );
    }

    // Whole-answer instruction detection (after line filter).
    final lowerAll = text.toLowerCase();
    final markerHits =
        _instructionMarkers.where((m) => lowerAll.contains(m)).length;
    if (markerHits >= 2) {
      return SanitizeResult.invalid(
        'The model echoed internal instructions instead of answering. Try again.',
      );
    }
    // Single strong identity leak at the start.
    if (lowerAll.startsWith('you are software') ||
        lowerAll.startsWith('you are projectevo') ||
        lowerAll.startsWith('answer the user')) {
      return SanitizeResult.invalid(
        'The model echoed internal instructions instead of answering. Try again.',
      );
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

    if (text.trim().isEmpty) {
      return SanitizeResult.invalid(
        'The model produced unusable output. Please rephrase.',
      );
    }

    return SanitizeResult.valid(text.trim());
  }

  /// Backward-compatible wrapper used by older call sites / tests.
  static String sanitize(String raw, {String? systemPrompt}) {
    final r = process(raw, systemPrompt: systemPrompt);
    return r.text;
  }

  static String _cutRepetition(String text) {
    if (text.length < minRepeatBlockChars * 2) return text;

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
          final rest = paras.skip(same).toList();
          if (rest.isEmpty) return first;
          return ([first, ...rest]).join('\n\n');
        }
      }
    }

    final n = text.length;
    for (var len = minRepeatBlockChars; len <= n ~/ 3; len++) {
      final block = text.substring(0, len);
      var count = 1;
      var pos = len;
      while (pos + len <= n && text.substring(pos, pos + len) == block) {
        count++;
        pos += len;
      }
      if (count >= 3) return block.trim();
    }

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

class SanitizeResult {
  final bool ok;
  final String text;

  const SanitizeResult._(this.ok, this.text);

  factory SanitizeResult.valid(String text) => SanitizeResult._(true, text);
  factory SanitizeResult.invalid(String message) =>
      SanitizeResult._(false, message);
}
