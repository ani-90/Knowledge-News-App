import 'dart:ui';
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

    // Strip table of contents blocks (heading + anchor-link list items)
    text = text.replaceAll(
      RegExp(
        r'#{1,4}\s*(table of contents|contents|toc|on this page|jump to|in this article|quick links)[^\n]*\n([ \t]*[-*\d.]+[ \t]+\[[^\]]*\]\(#[^\)]*\)\n?)+',
        caseSensitive: false,
        multiLine: true,
      ),
      '',
    );

    // Remove list items that are purely anchor links (ToC remnants)
    text = text.replaceAll(
      RegExp(r'^[ \t]*[-*\d.]+\.?[ \t]+\[[^\]]+\]\(#[^\)]*\)[ \t]*$', multiLine: true),
      '',
    );

    // Strip remaining inline anchor-only links
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(#[^\)]*\)'),
      (m) => m[1]!,
    );

    // Make bare URLs into markdown links
    text = text.replaceAllMapped(
      RegExp(r'(?<!\()(?<!\[)(https?://[^\s\)\]<>"]+)'),
      (m) => '[${m[1]}](${m[1]})',
    );

    // Remove lines that are purely a markdown link (nav menus, link dumps)
    final lines = text.split('\n');
    final cleaned = <String>[];
    int consecutiveLinkLines = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      final isLinkOnly = RegExp(r'^\[.*\]\(.*\)$').hasMatch(trimmed) ||
          RegExp(r'^[-*]\s+\[.*\]\(.*\)$').hasMatch(trimmed);
      if (isLinkOnly) {
        consecutiveLinkLines++;
        if (consecutiveLinkLines <= 1) cleaned.add(line);
      } else {
        consecutiveLinkLines = 0;
        cleaned.add(line);
      }
    }

    // Collapse 3+ blank lines into 2
    return cleaned.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  MarkdownStyleSheet _contentStyle(Color domainColor) => MarkdownStyleSheet(
        p: const TextStyle(fontSize: 15, height: 1.75, color: Colors.white),
        h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.8),
        h2: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, height: 1.8),
        h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, height: 1.7),
        h4: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, height: 1.7),
        strong: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        a: TextStyle(color: AppColors.accent, decoration: TextDecoration.underline),
        blockquote: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6), fontStyle: FontStyle.italic),
        code: TextStyle(fontSize: 13, fontFamily: 'monospace', backgroundColor: Colors.white.withValues(alpha: 0.10)),
      );

  MarkdownStyleSheet _summaryStyle() => MarkdownStyleSheet(
        p: TextStyle(fontSize: 14, height: 1.65, color: Colors.white.withValues(alpha: 0.9)),
        strong: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    final domainColor = AppColors.forDomain(_article.domain);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: domainColor.withValues(alpha: 0.35)),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _article.domain.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            Text(
              _article.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
                  : const Icon(Icons.auto_awesome, color: Colors.white),
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
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    onPressed: () {
                      context.read<DebateProvider>().reset(_article.id);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DebateScreen(article: _article, domainColor: domainColor),
                        ),
                      );
                    },
                    icon: Icon(Icons.forum_outlined, color: domainColor),
                    label: Text('Debate', style: TextStyle(color: domainColor, fontWeight: FontWeight.w600)),
                  ),
                  FloatingActionButton.extended(
                    heroTag: 'quiz_fab',
                    backgroundColor: domainColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    onPressed: () {
                      context.read<QuizProvider>().reset();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizScreen(
                            articleId: _article.id,
                            articleTitle: _article.title,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.quiz),
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
                  // Title (sticky in AppBar, also shown large here for reading context)
                  Text(
                    _article.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.source, size: 12, color: Colors.white.withValues(alpha: 0.45)),
                      const SizedBox(width: 4),
                      Text(_article.sourceName,
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                      const Spacer(),
                      Text(_formatDate(_article.fetchedAt),
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                    ],
                  ),

                  // Summary section — shown at top when triggered
                  AnimatedSize(
                    duration: const Duration(milliseconds: 350),
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
                  Divider(color: Colors.white.withValues(alpha: 0.12)),
                  const SizedBox(height: 16),

                  // Full article content
                  if (_article.hasFullContent) ...[
                    MarkdownBody(
                      data: _cleanContent(_article.rawContent),
                      styleSheet: _contentStyle(domainColor),
                      onTapLink: (_, href, __) { if (href != null) _openUrl(href); },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Paywalled notice
                  if (!_article.hasFullContent)
                    GestureDetector(
                      onTap: () => _openUrl(_article.sourceUrl),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Full article unavailable (paywalled). Tap to read on source.',
                                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
                              ),
                            ),
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 16, color: domainColor),
              const SizedBox(width: 8),
              Text(
                'AI SUMMARY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 1.4,
                ),
              ),
            ],
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
