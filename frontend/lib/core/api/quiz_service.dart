import '../models/quiz.dart';
import 'api_client.dart';

class QuizService {
  final ApiClient _client = ApiClient();

  Future<QuizSession> generateQuiz({
    required int articleId,
    int userId = 1,
  }) async {
    final res = await _client.post(
      '/api/quiz/generate',
      body: {'article_id': articleId, 'user_id': userId},
    );
    return QuizSession.fromJson(res.data as Map<String, dynamic>);
  }

  Future<QuizResult> submitAnswers({
    required int sessionId,
    required Map<String, String> answers,
  }) async {
    final res = await _client.post(
      '/api/quiz/submit',
      body: {'session_id': sessionId, 'answers': answers},
    );
    return QuizResult.fromJson(res.data as Map<String, dynamic>);
  }
}
