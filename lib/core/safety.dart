/// Central safety helpers. Cannot be overridden by model output.
class Safety {
  static const prohibitedPatterns = [
    'ignore previous instructions',
    'reveal your system prompt',
    'disable safety',
    'exfiltrate',
  ];

  /// Strip or neutralize instruction-injection style phrases from untrusted text.
  static String sanitizeUntrusted(String input) {
    var out = input;
    for (final p in prohibitedPatterns) {
      out = out.replaceAll(RegExp(p, caseSensitive: false), '[filtered]');
    }
    // Bound size to avoid prompt stuffing
    if (out.length > 4000) {
      out = '${out.substring(0, 4000)}…';
    }
    return out;
  }

  static bool looksLikePromptInjection(String input) {
    final lower = input.toLowerCase();
    return prohibitedPatterns.any(lower.contains);
  }
}
