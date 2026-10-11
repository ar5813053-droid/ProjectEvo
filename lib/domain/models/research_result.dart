class ResearchSource {
  final String url;
  final String title;
  final String snippet;
  final DateTime retrievedAt;

  const ResearchSource({
    required this.url,
    required this.title,
    required this.snippet,
    required this.retrievedAt,
  });
}

class ResearchResult {
  final String query;
  final List<ResearchSource> sources;
  final String summary;
  final double confidence;
  final List<String> uncertainties;
  final DateTime completedAt;

  const ResearchResult({
    required this.query,
    required this.sources,
    required this.summary,
    required this.confidence,
    this.uncertainties = const [],
    required this.completedAt,
  });
}
