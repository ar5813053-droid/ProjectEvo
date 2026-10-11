/// Ring-buffer of safe inference diagnostics for on-device debugging.
/// Never stores HF tokens, full prompts, memory content, or private user text.
class InferenceDiagnostics {
  static const int maxEntries = 80;
  final List<String> _lines = <String>[];
  final _listeners = <void Function()>[];

  List<String> get lines => List.unmodifiable(_lines);

  String get asText => _lines.isEmpty ? '(no diagnostics yet)' : _lines.join('\n');

  void add(String message) {
    final ts = DateTime.now().toUtc().toIso8601String().substring(11, 19);
    _lines.add('[$ts] $message');
    while (_lines.length > maxEntries) {
      _lines.removeAt(0);
    }
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void clear() {
    _lines.clear();
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
}
