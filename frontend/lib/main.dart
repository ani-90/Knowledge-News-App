import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/debate_provider.dart';
import 'core/providers/feed_provider.dart';
import 'core/providers/quiz_provider.dart';
import 'features/feed/home_screen.dart';
import 'shared/theme/app_theme.dart';

void main() {
  runApp(const KnowledgeNewsApp());
}

class KnowledgeNewsApp extends StatelessWidget {
  const KnowledgeNewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => DebateProvider()),
      ],
      child: MaterialApp(
        title: 'Knowledge News',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Container(
          decoration: const BoxDecoration(gradient: AppGradients.background),
          child: const HomeScreen(),
        ),
      ),
    );
  }
}
