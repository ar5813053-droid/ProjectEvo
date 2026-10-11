import 'package:flutter_test/flutter_test.dart';
import 'package:project_evo/data/inference/response_sanitizer.dart';

void main() {
  group('ResponseSanitizer', () {
    test('passes through a normal short greeting', () {
      const raw = 'Hi! How can I help you today?';
      expect(ResponseSanitizer.sanitize(raw), equals(raw));
    });

    test('passes through a normal answer', () {
      const raw =
          'Paris is the capital of France. It is known for the Eiffel Tower.';
      expect(ResponseSanitizer.sanitize(raw), equals(raw));
    });

    test('strips leaked system prompt markers', () {
      const raw = '''
You are ProjectEVO, a personal Android assistant.
Personality (simulated software state only — not real emotions or consciousness):
Relevant memory (user-approved local DB; may be incomplete):
None.

Hello! How can I help?
''';
      final out = ResponseSanitizer.sanitize(raw);
      expect(out.toLowerCase().contains('you are projectevo'), isFalse);
      expect(out.toLowerCase().contains('relevant memory'), isFalse);
      expect(out.toLowerCase().contains('hello'), isTrue);
    });

    test('cuts runaway paragraph repetition', () {
      const block =
          'I am a helpful assistant running on your device and I will answer carefully. ';
      final raw = List.filled(8, block.trim()).join('\n\n');
      final out = ResponseSanitizer.sanitize(raw);
      expect(out.length, lessThan(raw.length ~/ 2));
      expect(out.contains('helpful assistant'), isTrue);
    });

    test('handles empty output', () {
      final out = ResponseSanitizer.sanitize('   ');
      expect(out.toLowerCase().contains('empty'), isTrue);
    });

    test('strips invented eval footers via markers', () {
      const raw =
          'Sure, here is a tip.\n\n(Eval: 70% · Heuristic check passed)';
      final out = ResponseSanitizer.sanitize(raw);
      expect(out.toLowerCase().contains('eval:'), isFalse);
      expect(out.toLowerCase().contains('heuristic'), isFalse);
      expect(out.contains('tip'), isTrue);
    });

    test('respects soft max length', () {
      final raw = 'Word. ' * 500;
      final out = ResponseSanitizer.sanitize(raw);
      expect(out.length, lessThanOrEqualTo(ResponseSanitizer.maxChars + 5));
    });
  });
}
