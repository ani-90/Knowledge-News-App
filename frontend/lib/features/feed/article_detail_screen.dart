import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/feed_service.dart';
import '../../core/models/article.dart';
import '../../core/providers/debate_provider.dart';
import '../../core/providers/quiz_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../debate/debate_screen.dart';
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
  bool _showSummary = false;
  bool _summarizing = false;

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
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cleanContent(String text) {
    // Remove base64 images
    text = text.replaceAll(RegExp(r'!\[[^\]]*\]\(data:[^\)]+\)'), '');

    // Strip "Related / See Also / Further reading" sections entirely
    text = text.replaceAll(
      RegExp(
        r'#{1,4}\s*(related|see also|further reading|more from|read more|read next|'
        r'you might also|recommended|external links|references|sources|footnotes)[^\n]*\n(.*\n){0,20}',
        caseSensitive: false,
        multiLine: true,
      ),
      '',
    );

    // Strip ToC blocks (heading + anchor-link list)
    text = text.replaceAll(
      RegExp(
        r'#{1,4}\s*(table of contents|contents|toc|on this page|jump to|in this article|quick links)[^\n]*\n'
        r'([ \t]*[-*\d.]+[ \t]+\[[^\]]*\]\(#[^\)]*\)\n?)+',
        caseSensitive: false,
        multiLine: true,
      ),
      '',
    );

    // Remove ALL list items that are purely links (anchor or external)
    text = text.replaceAll(
      RegExp(r'^[ \t]*[-*\d.]+\.?[ \t]+\[[^\]]+\]\([^\)]*\)[ \t]*$', multiLine: true),
      '',
    );

    // Strip anchor-only inline links → keep just the text label
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(#[^\)]*\)'),
      (m) => m[1]!,
    );

    // Remove lines that are only a markdown link (no surrounding prose)
    text = text.replaceAll(
      RegExp(r'^\[.*\]\(https?://[^\)]+\)[ \t]*$', multiLine: true),
      '',
    );

    // Remove lines that are a bare URL only
    text = text.replaceAll(
      RegExp(r'^https?://\S+[ \t]*$', multiLine: true),
      '',
    );

    // Collapse 3+ blank lines → 2
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  MarkdownStyleSheet _contentStyle(Color domainColor) => MarkdownStyleSheet(
        p: const TextStyle(fontSize: 15, height: 1.8, color: Colors.white),
        h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.8),
        h2: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, height: 1.7),
        h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, height: 1.6),
        h4: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, height: 1.6),
        strong: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        em: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary),
        a: const TextStyle(color: AppColors.accent, decoration: TextDecoration.underline),
        blockquote: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
        code: const TextStyle(fontSize: 13, fontFamily: 'monospace', backgroundColor: AppColors.surfaceRaised, color: Colors.white),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.divider, width: 3)),
          color: AppColors.surfaceRaised,
        ),
      );

  MarkdownStyleSheet _summaryStyle() => const MarkdownStyleSheet(
        p: TextStyle(fontSize: 14, height: 1.7, color: AppColors.textSecondary),
        strong: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    final domainColor = AppColors.forDomain(_article.domain);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _article.domain.toUpperCase(),
              style: const TextStyle(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
            Text(
              _article.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: domainColor),
        ),
        actions: [
          if (!_showSummary)
            IconButton(
              icon: _summarizing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome),
              tooltip: 'Summarize',
              onPressed: _summarizing ? null : () => _handleSummarize(domainColor),
            ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open source',
            onPressed: () => _openUrl(_article.sourceUrl),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _loading
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'debate_fab',
                    backgroundColor: AppColors.surfaceRaised,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    onPressed: () {
                      context.read<DebateProvider>().reset(_article.id);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DebateScreen(article: _article, domainColor: domainColor),
                        ),
                      );
                    },
                    icon: Icon(Icons.forum_outlined, color: domainColor, size: 18),
                    label: Text('Debate', style: TextStyle(color: domainColor, fontWeight: FontWeight.w600)),
                  ),
                  FloatingActionButton.extended(
                    heroTag: 'quiz_fab',
                    backgroundColor: domainColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    onPressed: () {
                      context.read<QuizProvider>().reset();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizScreen(articleId: _article.id, articleTitle: _article.title),
                        ),
                      );
                    },
                    icon: const Icon(Icons.quiz, size: 18),
                    label: const Text('Quiz', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _article.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.35, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.source, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(_article.sourceName, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const Spacer(),
                      Text(_formatDate(_article.fetchedAt), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),

                  // Summary — shown at top when triggered
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showSummary
                        ? _SummarySection(
                            summary: _article.summary,
                            domainColor: domainColor,
                            styleSheet: _summaryStyle(),
                            onTapLink: _openUrl,
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 16),

                  if (_article.hasFullContent) ...[
                    MarkdownBody(
                      data: _cleanContent(_article.rawContent),
                      styleSheet: _contentStyle(domainColor),
                      onTapLink: (_, href, __) { if (href != null) _openUrl(href); },
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (!_article.hasFullContent)
                    GestureDetector(
                      onTap: () => _openUrl(_article.sourceUrl),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Full article unavailable (paywalled). Tap to read on source.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                            Icon(Icons.open_in_new, size: 13, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _handleSummarize(Color domainColor) async {
    if (_article.summary.isNotEmpty) {
      setState(() => _showSummary = true);
      return;
    }
    setState(() => _summarizing = true);
    try {
      final summary = await FeedService().summarizeArticle(_article.id);
      if (mounted) {
        setState(() {
          _article = _article.copyWith(summary: summary);
          _showSummary = true;
          _summarizing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

class _SummarySection extends StatelessWidget {
  final String summary;
  final Color domainColor;
  final MarkdownStyleSheet styleSheet;
  final Future<void> Function(String) onTapLink;

  const _SummarySection({
    required this.summary,
    required this.domainColor,
    required this.styleSheet,
    required this.onTapLink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: domainColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI SUMMARY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: domainColor,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          MarkdownBody(
            data: summary,
            styleSheet: styleSheet,
            onTapLink: (_, href, __) { if (href != null) onTapLink(href); },
          ),
        ],
      ),
    );
  }
}
