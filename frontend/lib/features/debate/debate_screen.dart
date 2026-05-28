import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/article.dart';
import '../../core/models/debate_message.dart';
import '../../core/providers/debate_provider.dart';
import '../../shared/theme/app_theme.dart';

class DebateScreen extends StatefulWidget {
  final Article article;
  final Color domainColor;

  const DebateScreen({
    super.key,
    required this.article,
    required this.domainColor,
  });

  @override
  State<DebateScreen> createState() => _DebateScreenState();
}

class _DebateScreenState extends State<DebateScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage(DebateProvider provider) {
    final text = _inputController.text.trim();
    if (text.isEmpty || provider.isLoading) return;
    _inputController.clear();
    provider.sendMessage(widget.article.id, text).then((_) => _scrollToBottom());
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final domainColor = widget.domainColor;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DEBATE',
              style: TextStyle(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: domainColor),
            ),
            Text(
              widget.article.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: domainColor),
        ),
      ),
      body: Consumer<DebateProvider>(
        builder: (context, provider, _) {
          final messages = provider.messages;
          final isLoading = provider.isLoading;
          final itemCount = messages.length + (isLoading ? 1 : 0);

          return Column(
            children: [
              if (messages.isEmpty && !isLoading)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.forum_outlined, size: 44, color: domainColor.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          const Text(
                            'Challenge the article',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Disagree with a claim? Push back and see how the argument holds up.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (index == messages.length && isLoading) {
                        return _TypingBubble(domainColor: domainColor);
                      }
                      return _MessageBubble(
                        message: messages[index],
                        domainColor: domainColor,
                      );
                    },
                  ),
                ),

              if (provider.error != null)
                Container(
                  color: const Color(0xFFFEF2F2),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Failed to get a response. Please try again.',
                          style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ),

              _InputBar(
                controller: _inputController,
                domainColor: domainColor,
                disabled: isLoading,
                onSend: () => _sendMessage(provider),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final DebateMessage message;
  final Color domainColor;

  const _MessageBubble({required this.message, required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.surfaceRaised,
              child: Icon(Icons.smart_toy_outlined, size: 15, color: domainColor),
            ),
            const SizedBox(width: 8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isUser ? domainColor : AppColors.surfaceRaised,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isUser ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.surfaceRaised,
              child: Icon(Icons.person_outline, size: 15, color: domainColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  final Color domainColor;
  const _TypingBubble({required this.domainColor});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> {
  late Timer _timer;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount % 3) + 1);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.surfaceRaised,
            child: Icon(Icons.smart_toy_outlined, size: 15, color: widget.domainColor),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Text(
              '.' * _dotCount,
              style: TextStyle(
                fontSize: 18,
                color: widget.domainColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final Color domainColor;
  final bool disabled;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.domainColor,
    required this.disabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !disabled,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Challenge a claim...',
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                final canSend = value.text.trim().isNotEmpty && !disabled;
                return IconButton(
                  onPressed: canSend ? onSend : null,
                  icon: const Icon(Icons.send_rounded),
                  color: domainColor,
                  disabledColor: AppColors.textMuted,
                  style: IconButton.styleFrom(
                    backgroundColor: canSend ? domainColor.withValues(alpha: 0.12) : Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
