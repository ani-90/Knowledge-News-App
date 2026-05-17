import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/article.dart';
import '../../core/providers/quiz_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../quiz/quiz_screen.dart';

class ArticleDetailScreen extends StatelessWidget {
  final Article article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final domainColor = AppColors.forDomain(article.domain);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: domainColor,
        title: Text(
          article.domain.toUpperCase(),
          style: const TextStyle(fontSize: 14, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open source',
            onPressed: () => _openUrl(article.sourceUrl),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.title,
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
                  article.sourceName,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  _formatDate(article.fetchedAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const Divider(height: 32),
            MarkdownBody(
              data: article.summary,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 16,
                  height: 1.7,
                  color: AppColors.textPrimary,
                ),
                h2: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                strong: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 32),
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
        builder: (_) => QuizScreen(articleId: article.id, articleTitle: article.title),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}