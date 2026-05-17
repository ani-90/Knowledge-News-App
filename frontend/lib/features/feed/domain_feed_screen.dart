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
      onRefresh: () => feed.loadDomain(widget.domain),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: articles.length,
        itemBuilder: (ctx, i) => _ArticleCard(article: articles[i]),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final Article article;
  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final domainColor = AppColors.forDomain(article.domain);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArticleDetailScreen(article: article),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: domainColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      article.domain.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: domainColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _timeAgo(article.fetchedAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                article.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                article.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.link, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      article.sourceName,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 12, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (ctx, i) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Container(height: 140),
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
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.article_outlined,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text('No articles yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Tap refresh to fetch the latest news',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Now'),
          ),
        ],
      ),
    );
  }
}