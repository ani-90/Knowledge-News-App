import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/feed_service.dart';
import '../../core/models/article.dart';
import '../../core/providers/quiz_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../quiz/quiz_screen.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late Article _article;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final detail = await FeedService().getArticleDetail(_article.id);
      if (mounted) setState(() { _article = detail; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// Convert bare URLs in plain text to markdown links so MarkdownBody renders them clickable.
  String _linkify(String text) {
    return text.replaceAllMapped(
      RegExp(r'(?<!\()(?<!\[)(https?://[^\s\)\]<>"]+)'),
      (m) => '[${m[1]}](${m[1]})',
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  MarkdownStyleSheet _contentStyle() => MarkdownStyleSheet(
    p: const TextStyle(fontSize: 15, height: 1.75, color: AppColors.textPrimary),
    h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 2),
    h2: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 2),
    h3: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.8),
    h4: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.8),
    strong: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    a: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
    blockquote: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
    code: const TextStyle(fontSize: 13, fontFamily: 'monospace', backgroundColor: Color(0xFFEEEEEE)),
  );

  MarkdownStyleSheet _summaryStyle() => MarkdownStyleSheet(
    p: const TextStyle(fontSize: 16, height: 1.7, color: AppColors.textPrimary),
    strong: const TextStyle(fontWeight: FontWeight.w600),
  );

  @override
  Widget build(BuildContext context) {
    final domainColor = AppColors.forDomain(_article.domain);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: domainColor,
        title: Text(
          _article.domain.toUpperCase(),
          style: const TextStyle(fontSize: 14, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open source',
            onPressed: () => _openUrl(_article.sourceUrl),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _article.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.source, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _article.sourceName,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(_article.fetchedAt),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Full article content
                  if (_article.hasFullContent) ...[
                    MarkdownBody(
                      data: _linkify(_article.rawContent),
                      styleSheet: _contentStyle(),
                      onTapLink: (_, href, __) { if (href != null) _openUrl(href); },
                    ),
                    const Divider(height: 40),
                    const Text(
                      'AI SUMMARY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Summary (always shown; smaller when full content is above)
                  MarkdownBody(
                    data: _article.summary,
                    styleSheet: _summaryStyle(),
                    onTapLink: (_, href, __) { if (href != null) _openUrl(href); },
                  ),

                  // Paywall notice
                  if (!_article.hasFullContent) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _openUrl(_article.sourceUrl),
                      child: Row(
                        children: const [
                          Icon(Icons.lock_outline, size: 13, color: AppColors.textSecondary),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Full article unavailable (paywalled or restricted). Tap to read on source.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: domainColor,
        onPressed: () => _startQuiz(context),
        icon: const Icon(Icons.quiz, color: Colors.white),
        label: const Text('Take Quiz',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _startQuiz(BuildContext context) {
    context.read<QuizProvider>().reset();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(articleId: _article.id, articleTitle: _article.title),
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
