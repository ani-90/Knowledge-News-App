import 'package:flutter/foundation.dart';
import '../api/quiz_service.dart';
import '../models/quiz.dart';

enum QuizState { idle, loading, loaded, submitting, done, error }

class QuizProvider extends ChangeNotifier {
  final QuizService _service = QuizService();

  QuizSession? _session;
  QuizResult? _result;
  QuizState _state = QuizState.idle;
  String? _errorMessage;
  final Map<int, String> _selectedAnswers = {};

  QuizSession? get session => _session;
  QuizResult? get result => _result;
  QuizState get state => _state;
  String? get errorMessage => _errorMessage;
  Map<int, String> get selectedAnswers => _selectedAnswers;

  void selectAnswer(int questionIndex, String answer) {
    _selectedAnswers[questionIndex] = answer;
    notifyListeners();
  }

  Future<void> generateQuiz(int articleId) async {
    _state = QuizState.loading;
    _session = null;
    _result = null;
    _selectedAnswers.clear();
    notifyListeners();
    try {
      _session = await _service.generateQuiz(articleId: articleId);
      _state = QuizState.loaded;
    } catch (e) {
      _state = QuizState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> submitAnswers() async {
    if (_session == null) return;
    _state = QuizState.submitting;
    notifyListeners();
    try {
      final answers = _selectedAnswers
          .map((k, v) => MapEntry(k.toString(), v));
      _result = await _service.submitAnswers(
        sessionId: _session!.sessionId,
        answers: answers,
      );
      _state = QuizState.done;
    } catch (e) {
      _state = QuizState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  void reset() {
    _session = null;
    _result = null;
    _state = QuizState.idle;
    _errorMessage = null;
    _selectedAnswers.clear();
    notifyListeners();
  }
}
