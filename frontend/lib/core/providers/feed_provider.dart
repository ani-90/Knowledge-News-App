import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/feed_service.dart';
import '../models/article.dart';
import '../models/pipeline_run.dart';

enum FeedState { idle, loading, loaded, error }

class FeedProvider extends ChangeNotifier {
  final FeedService _service = FeedService();

  final Map<String, List<Article>> _articlesByDomain = {};
  final Map<String, FeedState> _stateByDomain = {};
  final Map<String, String> _errorByDomain = {};
  PipelineRun? _lastRun;
  bool _isRefreshing = false;
  Timer? _pollTimer;

  PipelineRun? get lastRun => _lastRun;
  bool get isRefreshing => _isRefreshing;

  List<Article> articlesFor(String domain) => _articlesByDomain[domain] ?? [];
  FeedState stateFor(String domain) => _stateByDomain[domain] ?? FeedState.idle;
  String? errorFor(String domain) => _errorByDomain[domain];

  Future<void> loadDomain(String domain) async {
    _stateByDomain[domain] = FeedState.loading;
    notifyListeners();
    try {
      _articlesByDomain[domain] = await _service.getFeed(domain: domain);
      _stateByDomain[domain] = FeedState.loaded;
    } catch (e) {
      _stateByDomain[domain] = FeedState.error;
      _errorByDomain[domain] = e.toString();
    }
    notifyListeners();
  }

  Future<void> triggerRefresh() async {
    _isRefreshing = true;
    notifyListeners();
    try {
      final data = await _service.triggerRefresh();
      final status = data['status'] as String;

      if (status == 'skipped') {
        _lastRun = PipelineRun.skipped(
          runId: data['run_id'] as String,
          minutesAgo: (data['last_refreshed_minutes_ago'] as int?) ?? 0,
        );
        _isRefreshing = false;
        notifyListeners();
        return;
      }

      final runId = data['run_id'] as String;
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
        final run = await _service.getRunStatus(runId);
        _lastRun = run;
        notifyListeners();
        if (!run.isRunning) {
          _pollTimer?.cancel();
          _isRefreshing = false;
          notifyListeners();
          for (final domain in _articlesByDomain.keys.toList()) {
            await loadDomain(domain);
          }
        }
      });
    } catch (e) {
      _isRefreshing = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
