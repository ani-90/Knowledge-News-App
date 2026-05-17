import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/feed_provider.dart';
import '../../shared/theme/app_theme.dart';
import 'domain_feed_screen.dart';

const _domains = [
  ('finance', 'Finance', Icons.trending_up),
  ('politics', 'Politics', Icons.account_balance),
  ('ai_tech', 'AI & Tech', Icons.computer),
  ('law', 'Law', Icons.gavel),
  ('health', 'Health', Icons.favorite),
  ('fashion', 'Fashion', Icons.style),
  ('dharma', 'Dharma', Icons.self_improvement),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _domains.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Knowledge News',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          actions: [_RefreshButton()],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _domains
                .map((d) => Tab(
                      icon: Icon(d.$3, size: 18),
                      text: d.$2,
                    ))
                .toList(),
          ),
        ),
        body: Column(
          children: [
            _RefreshStatusBanner(),
            Expanded(
              child: TabBarView(
                children: _domains
                    .map((d) => DomainFeedScreen(domain: d.$1))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedProvider>();
    return IconButton(
      icon: feed.isRefreshing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.refresh),
      tooltip: 'Refresh all domains',
      onPressed: feed.isRefreshing
          ? null
          : () => context.read<FeedProvider>().triggerRefresh(),
    );
  }
}

class _RefreshStatusBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final run = context.watch<FeedProvider>().lastRun;
    if (run == null) return const SizedBox.shrink();

    final (color, message) = switch (run.status) {
      'running' => (AppColors.primary, 'Refreshing articles...'),
      'success' => (Colors.green.shade700,
          'Done — ${run.articlesAdded ?? 0} new articles added'),
      'partial' => (Colors.orange.shade700, 'Partial refresh completed'),
      _ => (Colors.red.shade700, 'Refresh failed'),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      width: double.infinity,
      child: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}
