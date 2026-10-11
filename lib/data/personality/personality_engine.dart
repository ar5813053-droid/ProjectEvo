import '../../domain/models/personality_state.dart';

class PersonalityEngine {
  PersonalityConfig _config = const PersonalityConfig();

  PersonalityConfig get config => _config;

  void update(PersonalityConfig config) {
    _config = config;
  }

  void setMood(SimulatedMood mood) {
    _config = _config.copyWith(mood: mood);
  }

  /// Compact system-prompt fragment. Explicitly non-sentient.
  String buildSystemFragment() {
    final c = _config;
    return 'Tone: ${c.moodLabel()}, verbosity ${c.verbosity.toStringAsFixed(1)}, '
        'curiosity ${c.curiosity.toStringAsFixed(1)}. '
        'Style: ${c.styleNotes}. '
        'Never claim consciousness or real emotions.';
  }
}
