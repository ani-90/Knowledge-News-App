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
  ('health', 'Health', Icons.favorite_border),
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: _domains.map((d) => Tab(icon: Icon(d.$3, size: 18), text: d.$2)).toList(),
                  ),
                ),
                _RefreshButton(),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            _RefreshStatusBanner(),
            Expanded(
              child: TabBarView(
                children: _domains.map((d) => DomainFeedScreen(domain: d.$1)).toList(),
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
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      tooltip: 'Refresh all domains',
      onPressed: feed.isRefreshing ? null : () => context.read<FeedProvider>().triggerRefresh(),
    );
  }
}

class _RefreshStatusBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final run = context.watch<FeedProvider>().lastRun;
    if (run == null) return const SizedBox.shrink();

    final minutesAgo = run.lastRefreshedMinutesAgo;
    final (color, textColor, message) = switch (run.status) {
      'running' => (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8), 'Refreshing articles...'),
      'success' => (const Color(0xFFF0FDF4), const Color(0xFF16A34A), 'Done — ${run.articlesAdded ?? 0} new articles added'),
      'partial'  => (const Color(0xFFFFFBEB), const Color(0xFFD97706), 'Partial refresh — ${run.articlesAdded ?? 0} new articles'),
      'skipped'  => (
          AppColors.surfaceRaised,
          AppColors.textSecondary,
          minutesAgo != null && minutesAgo < 60
              ? 'Already up to date — refreshed ${minutesAgo}m ago'
              : 'Already up to date',
        ),
      _ => (const Color(0xFFFEF2F2), const Color(0xFFDC2626), 'Refresh failed'),
    };

    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
      width: double.infinity,
      child: Text(
        message,
        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }
}
