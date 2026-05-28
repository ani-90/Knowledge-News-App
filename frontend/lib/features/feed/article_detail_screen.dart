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
    // Strip anchor-only links like [text](#section)
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(#[^\)]*\)'),
      (m) => m[1]!,
    );
    // Make bare URLs into markdown links
    text = text.replaceAllMapped(
      RegExp(r'(?<!\()(?<!\[)(https?://[^\s\)\]<>"]+)'),
      (m) => '[${m[1]}](${m[1]})',
    );
    // Collapse runs of 3+ consecutive link-only lines (navigation menus, link lists)
    text = text.replaceAll(
      RegExp(r'(\n\s*\[[^\]]+\]\([^\)]+\)\s*){3,}', multiLine: true),
      '\n',
    );
    // Remove lines that are purely a markdown link with no surrounding prose
    final lines = text.split('\n');
    final cleaned = <String>[];
    int consecutiveLinkLines = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      final isLinkOnly = RegExp(r'^\[.*\]\(.*\)$').hasMatch(trimmed) ||
          RegExp(r'^\*\s*\[.*\]\(.*\)$').hasMatch(trimmed) ||
          RegExp(r'^-\s*\[.*\]\(.*\)$').hasMatch(trimmed);
      if (isLinkOnly) {
        consecutiveLinkLines++;
        if (consecutiveLinkLines <= 2) cleaned.add(line); // keep first 2, drop the rest
      } else {
        consecutiveLinkLines = 0;
        cleaned.add(line);
      }
    }
    return cleaned.join('\n').trim();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  MarkdownStyleSheet _contentStyle(Color domainColor) => MarkdownStyleSheet(
        p: const TextStyle(fontSize: 15, height: 1.75, color: Colors.white),
        h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, height: 2),
        h2: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white, height: 2),
        h3: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white, height: 1.8),
        h4: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, height: 1.8),
        strong: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        a: TextStyle(color: AppColors.accent, decoration: TextDecoration.underline),
        blockquote: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6), fontStyle: FontStyle.italic),
        code: TextStyle(fontSize: 13, fontFamily: 'monospace', backgroundColor: Colors.white.withValues(alpha: 0.12)),
      );

  MarkdownStyleSheet _summaryStyle() => MarkdownStyleSheet(
        p: TextStyle(fontSize: 15, height: 1.7, color: Colors.white.withValues(alpha: 0.88)),
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
            child: Container(color: domainColor.withValues(alpha: 0.45)),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: Text(
          _article.domain.toUpperCase(),
          style: const TextStyle(fontSize: 13, letterSpacing: 1.2, fontWeight: FontWeight.w600),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _article.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Meta row
                  Row(
                    children: [
                      Icon(Icons.source, size: 13, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(_article.sourceName,
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
                      const Spacer(),
                      Text(_formatDate(_article.fetchedAt),
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 20),

                  // Full article content
                  if (_article.hasFullContent) ...[
                    MarkdownBody(
                      data: _cleanContent(_article.rawContent),
                      styleSheet: _contentStyle(domainColor),
                      onTapLink: (_, href, __) { if (href != null) _openUrl(href); },
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Paywalled notice
                  if (!_article.hasFullContent) ...[
                    GestureDetector(
                      onTap: () => _openUrl(_article.sourceUrl),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.inputFill,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Full article unavailable (paywalled or restricted). Tap to read on source.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Summary section (animated in)
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

                  const SizedBox(height: 16),
                ],
              ),
            ),
      bottomNavigationBar: _ActionBar(
        article: _article,
        domainColor: domainColor,
        loading: _loading,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Container(width: 4, height: 20, color: domainColor),
            const SizedBox(width: 10),
            Text(
              'AI SUMMARY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MarkdownBody(
          data: summary,
          styleSheet: styleSheet,
          onTapLink: (_, href, __) { if (href != null) onTapLink(href); },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  final Article article;
  final Color domainColor;
  final bool loading;

  const _ActionBar({
    required this.article,
    required this.domainColor,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(Icons.forum_outlined, size: 16, color: loading ? null : domainColor),
                label: Text(
                  'Debate',
                  style: TextStyle(
                    color: loading ? null : domainColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: loading ? Colors.white24 : domainColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: loading
                    ? null
                    : () {
                        context.read<DebateProvider>().reset(article.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DebateScreen(
                              article: article,
                              domainColor: domainColor,
                            ),
                          ),
                        );
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.quiz, size: 16),
                label: const Text('Take Quiz', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: loading ? null : domainColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                onPressed: loading
                    ? null
                    : () {
                        context.read<QuizProvider>().reset();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(
                              articleId: article.id,
                              articleTitle: article.title,
                            ),
                          ),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
