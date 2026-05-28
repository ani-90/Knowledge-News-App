import '../models/debate_message.dart';
import 'api_client.dart';

class DebateService {
  final ApiClient _client = ApiClient();

  Future<String> sendMessage({
    required int articleId,
    required String message,
    required List<DebateMessage> history,
  }) async {
    final res = await _client.post(
      '/api/debate/message',
      body: {
        'article_id': articleId,
        'user_id': 1,
        'message': message,
        'history': history.map((m) => m.toJson()).toList(),
      },
    );
    return res.data['reply'] as String;
  }
}
