import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/models/personality_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personality = ref.watch(personalityProvider);
    final inference = ref.watch(inferenceEngineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Model', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            title: Text(inference.name),
            subtitle: Text(inference.statusMessage ?? ''),
          ),
          const Divider(),
          Text('Simulated personality', style: Theme.of(context).textTheme.titleMedium),
          const Text(
            'Software state only — not real emotions or consciousness.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<SimulatedMood>(
            value: personality.mood,
            decoration: const InputDecoration(labelText: 'Mood (simulated)', border: OutlineInputBorder()),
            items: SimulatedMood.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                .toList(),
            onChanged: (m) {
              if (m != null) {
                ref.read(personalityProvider.notifier).update(personality.copyWith(mood: m));
              }
            },
          ),
          const SizedBox(height: 12),
          Text('Verbosity: ${personality.verbosity.toStringAsFixed(2)}'),
          Slider(
            value: personality.verbosity,
            onChanged: (v) => ref
                .read(personalityProvider.notifier)
                .update(personality.copyWith(verbosity: v)),
          ),
          Text('Curiosity: ${personality.curiosity.toStringAsFixed(2)}'),
          Slider(
            value: personality.curiosity,
            onChanged: (v) => ref
                .read(personalityProvider.notifier)
                .update(personality.copyWith(curiosity: v)),
          ),
          Text('Caution: ${personality.caution.toStringAsFixed(2)}'),
          Slider(
            value: personality.caution,
            onChanged: (v) => ref
                .read(personalityProvider.notifier)
                .update(personality.copyWith(caution: v)),
          ),
          const Divider(),
          const ListTile(
            title: Text('Privacy'),
            subtitle: Text(
              'No secrets in source. Memory stays on device. Export/delete from Memory tab. '
              'API keys (if added later) must use secure storage — never git.',
            ),
          ),
          const ListTile(
            title: Text('About ProjectEVO'),
            subtitle: Text(
              'Version 0.1.0 — evolving assistant: chat, memory, research, evaluation. '
              'On-device Gemma requires a verified runtime and small quantized model (see docs/MODELS.md).',
            ),
          ),
        ],
      ),
    );
  }
}
