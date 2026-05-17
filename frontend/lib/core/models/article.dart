class Article {
  final int id;
  final String title;
  final String summary;
  final String rawContent;
  final String domain;
  final String sourceUrl;
  final String sourceName;
  final DateTime fetchedAt;

  const Article({
    required this.id,
    required this.title,
    required this.summary,
    this.rawContent = '',
    required this.domain,
    required this.sourceUrl,
    required this.sourceName,
    required this.fetchedAt,
  });

  bool get hasFullContent => rawContent.length >= 500;

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id'] as int? ?? 0,
        title: json['title'] as String,
        summary: json['summary'] as String,
        rawContent: json['raw_content'] as String? ?? '',
        domain: json['domain'] as String,
        sourceUrl: json['url'] as String,
        sourceName: json['source'] as String,
        fetchedAt: json['fetched_at'] != null
            ? DateTime.parse(json['fetched_at'] as String)
            : DateTime.now(),
      );
}
