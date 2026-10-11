import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/providers.dart';
import '../../domain/models/model_info.dart';
import '../../domain/models/personality_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _hfTokenCtrl = TextEditingController();
  bool _busy = false;
  String? _actionError;

  @override
  void dispose() {
    _hfTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      var token = _hfTokenCtrl.text.trim();
      if (token.isEmpty) {
        token = await const FlutterSecureStorage().read(key: 'hf_token') ?? '';
      } else {
        await const FlutterSecureStorage().write(key: 'hf_token', value: token);
      }
      await ref.read(inferenceEngineProvider).downloadAndInstallModel(
            huggingFaceToken: token.isEmpty ? null : token,
          );
    } catch (e) {
      setState(() => _actionError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await ref.read(inferenceEngineProvider).ensureModelLoaded();
    } catch (e) {
      setState(() => _actionError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final personality = ref.watch(personalityProvider);
    final inference = ref.watch(inferenceEngineProvider);
    final runtimeAsync = ref.watch(modelRuntimeProvider);
    final runtime = runtimeAsync.valueOrNull ?? inference.modelState;
    final spec = ModelCatalog.defaultModel;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('On-device model', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${spec.displayName} · ~${spec.sizeLabel}\n${spec.description}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(inference.name),
            subtitle: Text(
              'Phase: ${runtime.phase.name}\n'
              '${runtime.message ?? ''}\n'
              '${runtime.error ?? ''}',
            ),
            isThreeLine: true,
          ),
          if (runtime.phase == ModelPhase.downloading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(value: runtime.downloadProgress),
            ),
          TextField(
            controller: _hfTokenCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Hugging Face token (optional)',
              hintText: 'hf_… if model is gated',
              border: OutlineInputBorder(),
              helperText: 'Stored in secure storage only — never committed.',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _download,
                  child: Text(_busy ? 'Working…' : 'Download & install'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Load model'),
                ),
              ),
            ],
          ),
          if (_actionError != null) ...[
            const SizedBox(height: 8),
            Text(_actionError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 8),
          Text(
            'License: ${spec.licenseNote}\n'
            'After install, chat uses the real model. Until then, replies are clearly marked Fallback.',
            style: const TextStyle(fontSize: 12),
          ),
          const Divider(height: 32),
          Text('Simulated personality', style: Theme.of(context).textTheme.titleMedium),
          const Text(
            'Software state only — not real emotions or consciousness.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<SimulatedMood>(
            initialValue: personality.mood,
            decoration: const InputDecoration(
              labelText: 'Mood (simulated)',
              border: OutlineInputBorder(),
            ),
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
          const Divider(height: 32),
          Text('Inference diagnostics', style: Theme.of(context).textTheme.titleMedium),
          const Text(
            'Safe logs for debugging empty replies. No HF tokens, full prompts, or memory contents.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 220),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                inference.diagnostics.asText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: inference.diagnostics.asText),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Diagnostics copied')),
                      );
                    }
                  },
                  child: const Text('Copy diagnostics'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    inference.diagnostics.clear();
                    setState(() {});
                  },
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'After sending “hi”, open this section and copy the lines. '
            'Share them if inference still fails. No PC required.',
            style: TextStyle(fontSize: 12),
          ),
          const Divider(),
          const ListTile(
            title: Text('Privacy'),
            subtitle: Text(
              'No secrets in source. Memory stays on device. Model weights stay in app storage, not git.',
            ),
          ),
          const ListTile(
            title: Text('About ProjectEVO'),
            subtitle: Text(
              'Version 0.3.x — on-device Gemma 3 270M when installed; otherwise labeled fallback. '
              'Memory/research do not change model weights.',
            ),
          ),
        ],
      ),
    );
  }
}
