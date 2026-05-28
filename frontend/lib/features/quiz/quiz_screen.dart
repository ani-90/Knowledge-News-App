// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/quiz.dart';
import '../../core/providers/quiz_provider.dart';
import '../../shared/theme/app_theme.dart';

// ─── Entry point ─────────────────────────────────────────────────────────────

class QuizScreen extends StatefulWidget {
  final int articleId;
  final String articleTitle;
  const QuizScreen({super.key, required this.articleId, required this.articleTitle});

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
    return switch (quiz.state) {
      QuizState.loading => _LoadingView(title: widget.articleTitle),
      QuizState.error => Scaffold(
          appBar: AppBar(title: const Text('Quiz')),
          body: _ErrorView(
            message: quiz.errorMessage ?? 'Failed to load quiz',
            onRetry: () => quiz.generateQuiz(widget.articleId),
          ),
        ),
      QuizState.loaded || QuizState.submitting => _QuizBody(
          session: quiz.session!,
          selectedAnswers: quiz.selectedAnswers,
          isSubmitting: quiz.state == QuizState.submitting,
          onSelect: quiz.selectAnswer,
          onSubmit: () => quiz.submitAnswers(),
        ),
      QuizState.done => _ResultView(result: quiz.result!, session: quiz.session!),
      _ => const Scaffold(body: SizedBox.shrink()),
    };
  }
}

// ─── Loading splash ───────────────────────────────────────────────────────────

class _LoadingView extends StatefulWidget {
  final String title;
  const _LoadingView({required this.title});

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Spacer(),
            ScaleTransition(
              scale: _pulse,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.quiz_rounded, size: 52, color: Colors.white),
              ),
            ),
            const SizedBox(height: 36),
            const Text(
              'QUIZ TIME',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 3.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Crafting your questions…',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(color: Colors.white30, strokeWidth: 2),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ─── Quiz body ────────────────────────────────────────────────────────────────

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
    final domainColor = AppColors.forDomain(session.domain);
    final answered = selectedAnswers.length;
    final total = session.questions.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUIZ',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w800,
                color: domainColor,
              ),
            ),
            Text(
              '$answered of $total answered',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: total == 0 ? 0 : answered / total),
            duration: const Duration(milliseconds: 300),
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(domainColor),
              minHeight: 3,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              itemCount: session.questions.length,
              itemBuilder: (_, i) => _QuestionCard(
                question: session.questions[i],
                selected: selectedAnswers[i],
                domainColor: domainColor,
                onSelect: (ans) => onSelect(i, ans),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: allAnswered ? domainColor : AppColors.divider,
                    foregroundColor: Colors.white,
                    elevation: allAnswered ? 2 : 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (allAnswered && !isSubmitting) ? onSubmit : null,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          allAnswered ? 'Submit Answers →' : 'Answer all $total questions',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final QuizQuestion question;
  final String? selected;
  final Color domainColor;
  final void Function(String) onSelect;

  const _QuestionCard({
    required this.question,
    required this.selected,
    required this.domainColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: domainColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Q${question.index + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: domainColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              question.question,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...question.optionLabels.map((label) {
              final isSelected = selected == label;
              return GestureDetector(
                onTap: () => onSelect(label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? domainColor : AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? domainColor : AppColors.divider,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.2) : AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white54 : AppColors.divider,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          question.options[label]!,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
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

// ─── Result view ──────────────────────────────────────────────────────────────

class _ResultView extends StatefulWidget {
  final QuizResult result;
  final QuizSession session;
  const _ResultView({required this.result, required this.session});

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  ({String label, String title, Color color}) get _grade {
    final pct = widget.result.percentage;
    if (pct >= 1.0) return (label: 'S', title: 'PERFECT!',    color: const Color(0xFFFFBF00));
    if (pct >= 0.8) return (label: 'A', title: 'EXCELLENT',   color: const Color(0xFF16A34A));
    if (pct >= 0.6) return (label: 'B', title: 'GOOD JOB',    color: const Color(0xFF2563EB));
    if (pct >= 0.4) return (label: 'C', title: 'KEEP GOING',  color: const Color(0xFFD97706));
    return               (label: 'D', title: 'STUDY MORE',  color: const Color(0xFFDC2626));
  }

  @override
  Widget build(BuildContext context) {
    final grade = _grade;
    final pct = widget.result.percentage;
    final domainColor = AppColors.forDomain(widget.session.domain);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: domainColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.session.domain.toUpperCase().replaceAll('_', ' '),
                      style: TextStyle(
                        color: domainColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // Score hero
            Expanded(
              flex: 2,
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: grade.color.withOpacity(0.18),
                          shape: BoxShape.circle,
                          border: Border.all(color: grade.color, width: 2.5),
                        ),
                        child: Center(
                          child: Text(
                            grade.label,
                            style: TextStyle(
                              color: grade.color,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        grade.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 130,
                        height: 130,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: pct),
                          duration: const Duration(milliseconds: 950),
                          curve: Curves.easeOutCubic,
                          builder: (_, value, __) => Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: value,
                                strokeWidth: 8,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation(grade.color),
                                strokeCap: StrokeCap.round,
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${widget.result.correctCount}/${widget.result.totalQuestions}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${(value * 100).round()}%',
                                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Breakdown sheet
            Expanded(
              flex: 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'BREAKDOWN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          ...widget.result.breakdown.map((b) => _BreakdownCard(item: b)),
                          const SizedBox(height: 4),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Back to Article', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final QuizAnswerBreakdown item;
  const _BreakdownCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.isCorrect ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  item.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.question,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your answer: ${item.yourAnswer}',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          if (!item.isCorrect)
            Text(
              'Correct: ${item.correctAnswer}',
              style: const TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          if (item.explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.explanation,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
