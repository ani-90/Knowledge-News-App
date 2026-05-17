import '../models/user_stats.dart';
import 'api_client.dart';

class StatsService {
  final ApiClient _client = ApiClient();

  Future<UserStats> getUserStats({int userId = 1}) async {
    final res = await _client.get('/api/user/stats', params: {'user_id': userId});
    return UserStats.fromJson(res.data as Map<String, dynamic>);
  }
}
