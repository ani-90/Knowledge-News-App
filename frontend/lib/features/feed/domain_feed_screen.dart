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

    if (feed.state == FeedState.loading && articles.isEmpty) return const _ShimmerList();
    if (feed.state == FeedState.error && articles.isEmpty) {
      return _ErrorView(
        message: feed.errorMessage ?? 'Something went wrong',
        onRetry: () => feed.loadDomain(widget.domain),
      );
    }
    if (articles.isEmpty) return _EmptyView(onRefresh: () => feed.triggerRefresh());

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: AppColors.surface,
      onRefresh: () => feed.loadDomain(widget.domain),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: articles.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
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

  @override
  Widget build(BuildContext context) {
    final domainColor = AppColors.forDomain(article.domain);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Domain colour accent bar
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: domainColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: domainColor.withValues(alpha: 0.15),
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
                            _timeAgo(article.fetchedAt),
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.link, size: 11, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              article.sourceName,
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
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
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 6,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Shimmer.fromColors(
          baseColor: AppColors.surface,
          highlightColor: AppColors.surfaceRaised,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surface,
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
            const Icon(Icons.wifi_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('Could not load articles',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
            const Icon(Icons.article_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('No articles yet',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Tap refresh to fetch the latest news',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
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
