import 'package:flutter_test/flutter_test.dart';
import 'package:project_evo/data/inference/response_sanitizer.dart';

void main() {
  group('ResponseSanitizer', () {
    test('passes through a normal short greeting', () {
      const raw = 'Hi! How can I help you today?';
      final r = ResponseSanitizer.process(raw);
      expect(r.ok, isTrue);
      expect(r.text, equals(raw));
    });

    test('passes through a normal answer', () {
      const raw =
          'Paris is the capital of France. It is known for the Eiffel Tower.';
      final r = ResponseSanitizer.process(raw);
      expect(r.ok, isTrue);
      expect(r.text, contains('Paris'));
    });

    test('rejects real-device style system instruction leak', () {
      // Exact pattern reported from POCO X3 Pro after prior fix.
      const raw =
          'You are software only — not conscious or sentient. '
          'Answer the user\'s message directly and briefly. '
          'Tone: Curious, verbosity 0.5, curiosity 0.6. '
          'Style: Helpful, honest, clear... None.]';
      final r = ResponseSanitizer.process(raw);
      expect(r.ok, isFalse);
      expect(r.text.toLowerCase().contains('echoed'), isTrue);
    });

    test('strips None.] residue', () {
      const raw = 'Hello there!\nNone.]';
      final r = ResponseSanitizer.process(raw);
      expect(r.ok, isTrue);
      expect(r.text.toLowerCase().contains('none'), isFalse);
      expect(r.text.contains('Hello'), isTrue);
    });

    test('rejects empty output', () {
      final r = ResponseSanitizer.process('   ');
      expect(r.ok, isFalse);
    });

    test('cuts runaway paragraph repetition', () {
      const block =
          'I am a helpful assistant running on your device and I will answer carefully.';
      final raw = List.filled(8, block).join('\n\n');
      final r = ResponseSanitizer.process(raw);
      expect(r.ok, isTrue);
      expect(r.text.length, lessThan(raw.length ~/ 2));
    });

    test('sanitize wrapper still returns string for tests', () {
      expect(
        ResponseSanitizer.sanitize('Hi!'),
        equals('Hi!'),
      );
    });
  });
}
