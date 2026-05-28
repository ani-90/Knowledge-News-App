import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/models/article.dart';
import '../../core/providers/feed_provider.dart';
import '../../shared/theme/app_theme.dart';
import 'article_detail_screen.dart';

class DomainFeedScreen extends StatefulWidget {
  final String domain;
  const DomainFeedScreen({super.key, required this.domain});

  @override
  State<DomainFeedScreen> createState() => _DomainFeedScreenState();
}

class _DomainFeedScreenState extends State<DomainFeedScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().loadDomain(widget.domain);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = context.watch<FeedProvider>();
    final articles = feed.articlesFor(widget.domain);

    if (feed.state == FeedState.loading && articles.isEmpty) {
      return _ShimmerList();
    }

    if (feed.state == FeedState.error && articles.isEmpty) {
      return _ErrorView(
        message: feed.errorMessage ?? 'Something went wrong',
        onRetry: () => feed.loadDomain(widget.domain),
      );
    }

    if (articles.isEmpty) {
      return _EmptyView(onRefresh: () => feed.triggerRefresh());
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => feed.loadDomain(widget.domain),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: articles.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ArticleCard(article: articles[i]),
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final Article article;
  const _ArticleCard({required this.article});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _readingTime(Article article) {
    final charCount = article.summary.length;
    final mins = (charCount / 200).ceil().clamp(1, 99);
    return '$mins min read';
  }

  @override
  Widget build(BuildContext context) {
    final domainColor = AppColors.forDomain(article.domain);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArticleDetailScreen(article: article),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left domain color bar
                  Container(width: 4, color: domainColor),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top meta: domain badge + time
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: domainColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  article.domain.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: domainColor,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_timeAgo(article.fetchedAt)}  ·  ${_readingTime(article)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Title
                          Text(
                            article.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Source row
                          Row(
                            children: [
                              const Icon(Icons.link, size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  article.sourceName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 11, color: AppColors.textSecondary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 5,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade50,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('Could not load articles',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('No articles yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Tap refresh to fetch the latest news',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Now'),
            ),
          ],
        ),
      ),
    );
  }
}
