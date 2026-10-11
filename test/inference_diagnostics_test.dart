import 'package:flutter_test/flutter_test.dart';
import 'package:project_evo/data/inference/inference_diagnostics.dart';

void main() {
  test('ring buffer keeps recent lines only', () {
    final d = InferenceDiagnostics();
    for (var i = 0; i < InferenceDiagnostics.maxEntries + 10; i++) {
      d.add('line $i');
    }
    expect(d.lines.length, InferenceDiagnostics.maxEntries);
    expect(d.asText.contains('line ${InferenceDiagnostics.maxEntries + 9}'), isTrue);
    expect(d.asText.contains('line 0'), isFalse);
  });

  test('clear empties buffer', () {
    final d = InferenceDiagnostics();
    d.add('x');
    d.clear();
    expect(d.lines, isEmpty);
  });
}
