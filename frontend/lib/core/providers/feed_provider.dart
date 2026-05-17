import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/feed_service.dart';
import '../models/article.dart';
import '../models/pipeline_run.dart';

enum FeedState { idle, loading, loaded, error }

class FeedProvider extends ChangeNotifier {
  final FeedService _service = FeedService();

  final Map<String, List<Article>> _articlesByDomain = {};
  FeedState _state = FeedState.idle;
  String? _errorMessage;
  PipelineRun? _lastRun;
  bool _isRefreshing = false;
  Timer? _pollTimer;

  FeedState get state => _state;
  String? get errorMessage => _errorMessage;
  PipelineRun? get lastRun => _lastRun;
  bool get isRefreshing => _isRefreshing;

  List<Article> articlesFor(String domain) =>
      _articlesByDomain[domain] ?? [];

  Future<void> loadDomain(String domain) async {
    _state = FeedState.loading;
    notifyListeners();
    try {
      _articlesByDomain[domain] = await _service.getFeed(domain: domain);
      _state = FeedState.loaded;
    } catch (e) {
      _state = FeedState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> triggerRefresh() async {
    _isRefreshing = true;
    notifyListeners();
    try {
      final runId = await _service.triggerRefresh();
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
        final run = await _service.getRunStatus(runId);
        _lastRun = run;
        notifyListeners();
        if (!run.isRunning) {
          _pollTimer?.cancel();
          _isRefreshing = false;
          notifyListeners();
          // Reload all cached domains after refresh
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
