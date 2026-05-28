import '../models/article.dart';
import '../models/pipeline_run.dart';
import 'api_client.dart';

class FeedService {
  final ApiClient _client = ApiClient();

  Future<List<Article>> getFeed({String? domain, int limit = 20}) async {
    final res = await _client.get(
      '/api/feed',
      params: {
        'domain': domain,
        'limit': limit,
      }..removeWhere((_, v) => v == null),
    );
    final articles = (res.data as Map<String, dynamic>)['articles'] as List;
    return articles
        .map((e) => Article.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> triggerRefresh({int userId = 1}) async {
    final res = await _client.post(
      '/api/feed/refresh',
      body: {'user_id': userId},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Article> getArticleDetail(int articleId) async {
    final res = await _client.get('/api/feed/$articleId');
    return Article.fromJson(res.data as Map<String, dynamic>);
  }

  Future<String> summarizeArticle(int articleId) async {
    final res = await _client.post('/api/feed/$articleId/summarize');
    return res.data['summary'] as String;
  }

  Future<PipelineRun> getRunStatus(String runId) async {
    final res = await _client.get('/api/feed/status/$runId');
    return PipelineRun.fromJson(res.data as Map<String, dynamic>);
  }
}
