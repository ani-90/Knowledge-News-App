// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/quiz.dart';
import '../../core/providers/quiz_provider.dart';
import '../../shared/theme/app_theme.dart';

class QuizScreen extends StatefulWidget {
  final int articleId;
  final String articleTitle;
  const QuizScreen({
    super.key,
    required this.articleId,
    required this.articleTitle,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizProvider>().generateQuiz(widget.articleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        backgroundColor: AppColors.primary,
      ),
      body: switch (quiz.state) {
        QuizState.loading => const Center(child: CircularProgressIndicator()),
        QuizState.error => _ErrorView(
            message: quiz.errorMessage ?? 'Failed to load quiz',
            onRetry: () => quiz.generateQuiz(widget.articleId),
          ),
        QuizState.loaded || QuizState.submitting => _QuizBody(
            session: quiz.session!,
            selectedAnswers: quiz.selectedAnswers,
            isSubmitting: quiz.state == QuizState.submitting,
            onSelect: quiz.selectAnswer,
            onSubmit: () => quiz.submitAnswers(),
          ),
        QuizState.done => _ResultView(result: quiz.result!),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _QuizBody extends StatelessWidget {
  final QuizSession session;
  final Map<int, String> selectedAnswers;
  final bool isSubmitting;
  final void Function(int, String) onSelect;
  final VoidCallback onSubmit;

  const _QuizBody({
    required this.session,
    required this.selectedAnswers,
    required this.isSubmitting,
    required this.onSelect,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final allAnswered = selectedAnswers.length == session.questions.length;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: session.questions.length,
            itemBuilder: (_, i) => _QuestionCard(
              question: session.questions[i],
              selected: selectedAnswers[i],
              onSelect: (ans) => onSelect(i, ans),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (allAnswered && !isSubmitting) ? onSubmit : null,
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        allAnswered
                            ? 'Submit Answers'
                            : 'Answer all questions to submit',
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final QuizQuestion question;
  final String? selected;
  final void Function(String) onSelect;

  const _QuestionCard({
    required this.question,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${question.index + 1}. ${question.question}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            ...question.optionLabels.map((label) {
              final text = question.options[label]!;
              return InkWell(
                onTap: () => onSelect(label),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: label,
                        groupValue: selected,
                        onChanged: (v) => onSelect(v!),
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$label.  $text',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final QuizResult result;
  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final pct = result.percentage;
    final (emoji, message) = switch (pct) {
      >= 0.8 => ('🎉', 'Excellent!'),
      >= 0.6 => ('👍', 'Good job!'),
      >= 0.4 => ('📚', 'Keep reading!'),
      _ => ('💪', 'Keep practising!'),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            '${result.correctCount} / ${result.totalQuestions}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          Text(
            '${(pct * 100).toStringAsFixed(0)}% correct',
            style: const TextStyle(
                fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),
          ...result.breakdown.map((b) => _BreakdownCard(item: b)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Article'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final QuizAnswerBreakdown item;
  const _BreakdownCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.isCorrect ? Colors.green.shade700 : Colors.red.shade700;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.isCorrect ? Icons.check_circle : Icons.cancel,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.question,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Your answer: ${item.yourAnswer}',
                style: TextStyle(color: color, fontSize: 13)),
            if (!item.isCorrect)
              Text('Correct: ${item.correctAnswer}',
                  style: TextStyle(
                      color: Colors.green.shade700, fontSize: 13)),
            if (item.explanation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.explanation,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
