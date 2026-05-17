class UserStats {
  final int userId;
  final int articlesRead;
  final int quizzesTaken;
  final double averageQuizScore;
  final Map<String, int> articlesByDomain;

  const UserStats({
    required this.userId,
    required this.articlesRead,
    required this.quizzesTaken,
    required this.averageQuizScore,
    required this.articlesByDomain,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        userId: json['user_id'] as int,
        articlesRead: json['articles_read'] as int,
        quizzesTaken: json['quizzes_taken'] as int,
        averageQuizScore: (json['average_quiz_score'] as num).toDouble(),
        articlesByDomain:
            Map<String, int>.from(json['articles_by_domain'] as Map),
      );
}
