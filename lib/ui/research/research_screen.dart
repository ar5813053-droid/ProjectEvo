import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/models/memory_item.dart';
import '../../domain/models/research_result.dart';

class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  final _query = TextEditingController();
  ResearchResult? _result;
  bool _busy = false;

  Future<void> _run() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    final r = await ref.read(researchServiceProvider).research(q);
    if (mounted) {
      setState(() {
        _result = r;
        _busy = false;
      });
    }
  }

  Future<void> _saveToMemory() async {
    final r = _result;
    if (r == null || r.sources.isEmpty) return;
    await ref.read(memoryRepositoryProvider).save(
          category: MemoryCategory.researchKnowledge,
          title: 'Research: ${r.query}',
          content: '${r.summary}\n\nSources:\n${r.sources.map((s) => '- ${s.title}: ${s.url}').join('\n')}',
          sourceUrl: r.sources.first.url,
          sourceTitle: r.sources.first.title,
          confidence: r.confidence,
          userApproved: true,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to memory (local DB)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Research')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Authorized lookup only. Web text is untrusted and never treated as system instructions. '
            'Respects rate limits; does not bypass CAPTCHA or paywalls.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            decoration: const InputDecoration(
              labelText: 'Research question',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _run(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _run,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Search'),
          ),
          if (r != null) ...[
            const SizedBox(height: 16),
            Text('Confidence: ${(r.confidence * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(r.summary),
            if (r.uncertainties.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Uncertainties: ${r.uncertainties.join('; ')}',
                  style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 12),
            ...r.sources.map(
              (s) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.title),
                subtitle: Text('${s.url}\n${s.snippet}', maxLines: 4),
                isThreeLine: true,
              ),
            ),
            if (r.sources.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _saveToMemory,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save approved knowledge to memory'),
              ),
          ],
        ],
      ),
    );
  }
}
