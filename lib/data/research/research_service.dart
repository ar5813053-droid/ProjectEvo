import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/research_result.dart';

/// Authorized research only. Never bypasses CAPTCHA/auth. Treats web as untrusted.
abstract class ResearchService {
  Future<ResearchResult> research(String query);
}

/// Uses DuckDuckGo Instant Answer API (no key) for lightweight lookup.
/// Not a full web crawl — honest limitations applied.
class DuckDuckGoResearchService implements ResearchService {
  final http.Client _client;

  DuckDuckGoResearchService({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<ResearchResult> research(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return ResearchResult(
        query: q,
        sources: const [],
        summary: 'Empty query.',
        confidence: 0,
        uncertainties: const ['No query provided'],
        completedAt: DateTime.now().toUtc(),
      );
    }

    try {
      final uri = Uri.https('api.duckduckgo.com', '/', {
        'q': q,
        'format': 'json',
        'no_redirect': '1',
        'no_html': '1',
        'skip_disambig': '1',
      });
      final resp = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        return ResearchResult(
          query: q,
          sources: const [],
          summary: 'Search provider returned HTTP ${resp.statusCode}.',
          confidence: 0.1,
          uncertainties: const ['Provider error'],
          completedAt: DateTime.now().toUtc(),
        );
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final abstract = (data['AbstractText'] as String?)?.trim() ?? '';
      final abstractUrl = (data['AbstractURL'] as String?) ?? '';
      final heading = (data['Heading'] as String?) ?? q;
      final sources = <ResearchSource>[];

      if (abstract.isNotEmpty && abstractUrl.isNotEmpty) {
        sources.add(ResearchSource(
          url: abstractUrl,
          title: heading,
          snippet: abstract.length > 400 ? '${abstract.substring(0, 400)}…' : abstract,
          retrievedAt: DateTime.now().toUtc(),
        ));
      }

      final related = data['RelatedTopics'];
      if (related is List) {
        for (final item in related.take(5)) {
          if (item is Map<String, dynamic>) {
            final text = (item['Text'] as String?) ?? '';
            final url = (item['FirstURL'] as String?) ?? '';
            if (text.isNotEmpty && url.isNotEmpty) {
              sources.add(ResearchSource(
                url: url,
                title: text.length > 80 ? '${text.substring(0, 80)}…' : text,
                snippet: text,
                retrievedAt: DateTime.now().toUtc(),
              ));
            }
          }
        }
      }

      if (sources.isEmpty) {
        return ResearchResult(
          query: q,
          sources: const [],
          summary:
              'No structured instant-answer results. Try a more specific query, or configure another search API later.',
          confidence: 0.2,
          uncertainties: const [
            'Instant Answer API coverage is limited',
            'Not a full web index',
          ],
          completedAt: DateTime.now().toUtc(),
        );
      }

      final summary = sources.first.snippet;
      return ResearchResult(
        query: q,
        sources: sources,
        summary: summary,
        confidence: sources.length >= 2 ? 0.55 : 0.4,
        uncertainties: const [
          'Web content is untrusted; verify important claims',
          'Single-provider lookup',
        ],
        completedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      return ResearchResult(
        query: q,
        sources: const [],
        summary: 'Network or parse error: $e',
        confidence: 0,
        uncertainties: const ['Offline or blocked network'],
        completedAt: DateTime.now().toUtc(),
      );
    }
  }
}
