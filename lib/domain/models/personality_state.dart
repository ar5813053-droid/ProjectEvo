/// Simulated software state — not genuine emotion or consciousness.
enum SimulatedMood {
  curious,
  focused,
  calm,
  enthusiastic,
  cautious,
  taskFrustrated,
  taskSatisfied,
}

class PersonalityConfig {
  final SimulatedMood mood;
  final double verbosity;
  final double curiosity;
  final double caution;
  final String styleNotes;

  const PersonalityConfig({
    this.mood = SimulatedMood.curious,
    this.verbosity = 0.5,
    this.curiosity = 0.6,
    this.caution = 0.4,
    this.styleNotes = 'Helpful, honest, clear. Never claim consciousness.',
  });

  PersonalityConfig copyWith({
    SimulatedMood? mood,
    double? verbosity,
    double? curiosity,
    double? caution,
    String? styleNotes,
  }) {
    return PersonalityConfig(
      mood: mood ?? this.mood,
      verbosity: verbosity ?? this.verbosity,
      curiosity: curiosity ?? this.curiosity,
      caution: caution ?? this.caution,
      styleNotes: styleNotes ?? this.styleNotes,
    );
  }

  String moodLabel() {
    switch (mood) {
      case SimulatedMood.curious:
        return 'Curious';
      case SimulatedMood.focused:
        return 'Focused';
      case SimulatedMood.calm:
        return 'Calm';
      case SimulatedMood.enthusiastic:
        return 'Enthusiastic';
      case SimulatedMood.cautious:
        return 'Cautious';
      case SimulatedMood.taskFrustrated:
        return 'Task-frustrated (sim)';
      case SimulatedMood.taskSatisfied:
        return 'Task-satisfied (sim)';
    }
  }
}
