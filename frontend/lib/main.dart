import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      ],
      child: MaterialApp(
        title: 'Knowledge News',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const HomeScreen(),
      ),
    );
  }
}
