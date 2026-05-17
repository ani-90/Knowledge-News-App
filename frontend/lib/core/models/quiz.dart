class QuizQuestion {
  final int index;
  final String question;
  final Map<String, String> options; // {A: "...", B: "...", C: "...", D: "..."}
  final String? explanation;

  const QuizQuestion({
    required this.index,
    required this.question,
    required this.options,
    this.explanation,
  });

  factory QuizQuestion.fromJson(int index, Map<String, dynamic> json) {
    final rawOpts = json['options'] as Map<String, dynamic>;
    return QuizQuestion(
      index: index,
      question: json['question'] as String,
      options: rawOpts.map((k, v) => MapEntry(k, v as String)),
      explanation: json['explanation'] as String?,
    );
  }

  List<String> get optionLabels => options.keys.toList()..sort();
}

class QuizSession {
  final int sessionId;
  final int articleId;
  final String domain;
  final List<QuizQuestion> questions;

  const QuizSession({
    required this.sessionId,
    required this.articleId,
    required this.domain,
    required this.questions,
  });

  factory QuizSession.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List;
    return QuizSession(
      sessionId: json['session_id'] as int,
      articleId: json['article_id'] as int,
      domain: json['domain'] as String? ?? '',
      questions: rawQuestions
          .asMap()
          .entries
          .map((e) => QuizQuestion.fromJson(
              e.key, e.value as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuizAnswerBreakdown {
  final String question;
  final String yourAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final String explanation;

  const QuizAnswerBreakdown({
    required this.question,
    required this.yourAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.explanation,
  });

  factory QuizAnswerBreakdown.fromJson(Map<String, dynamic> json) =>
      QuizAnswerBreakdown(
        question: json['question'] as String,
        yourAnswer: json['your_answer'] as String,
        correctAnswer: json['correct_answer'] as String,
        isCorrect: json['is_correct'] as bool,
        explanation: json['explanation'] as String,
      );
}

class QuizResult {
  final int sessionId;
  final double score;
  final int correctCount;
  final int totalQuestions;
  final List<QuizAnswerBreakdown> breakdown;

  const QuizResult({
    required this.sessionId,
    required this.score,
    required this.correctCount,
    required this.totalQuestions,
    required this.breakdown,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
        sessionId: json['session_id'] as int,
        score: (json['score'] as num).toDouble(),
        correctCount: json['correct_count'] as int,
        totalQuestions: json['total_questions'] as int,
        breakdown: (json['breakdown'] as List)
            .map((e) =>
                QuizAnswerBreakdown.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  double get percentage =>
      totalQuestions == 0 ? 0 : correctCount / totalQuestions;
}
