import 'package:flutter/foundation.dart';
import '../api/debate_service.dart';
import '../models/debate_message.dart';

class DebateProvider extends ChangeNotifier {
  final DebateService _service = DebateService();

  List<DebateMessage> _messages = [];
  bool _isLoading = false;
  int? _currentArticleId;
  String? error;

  List<DebateMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  void reset(int articleId) {
    if (_currentArticleId == articleId) return;
    _messages = [];
    _currentArticleId = articleId;
    error = null;
    notifyListeners();
  }

  Future<void> sendMessage(int articleId, String message) async {
    reset(articleId); // no-op if same article
    final historySnapshot = List<DebateMessage>.from(_messages); // snapshot BEFORE appending
    _messages = [..._messages, DebateMessage(role: 'user', content: message)];
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      final reply = await _service.sendMessage(
        articleId: articleId,
        message: message,
        history: historySnapshot,
      );
      _messages = [..._messages, DebateMessage(role: 'assistant', content: reply)];
    } catch (e) {
      error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
