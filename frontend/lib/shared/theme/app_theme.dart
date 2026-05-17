import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1A237E);      // deep indigo
  static const accent = Color(0xFFFF6F00);        // amber
  static const background = Color(0xFFF5F5F5);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);

  static const domainColors = <String, Color>{
    'finance': Color(0xFF1B5E20),
    'politics': Color(0xFF880E4F),
    'ai_tech': Color(0xFF0D47A1),
    'law': Color(0xFF4A148C),
    'health': Color(0xFF004D40),
    'fashion': Color(0xFFBF360C),
    'dharma': Color(0xFFE65100),
  };

  static Color forDomain(String domain) =>
      domainColors[domain] ?? primary;
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
        ),
      );
}