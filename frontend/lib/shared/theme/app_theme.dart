import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const primary = Color(0xFF1A237E); // deep indigo
  static const primaryLight = Color(0xFF283593);
  static const accent = Color(0xFFFF6F00); // amber
  static const background = Color(0xFFF2F4F8);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const divider = Color(0xFFE5E7EB);
  static const inputFill = Color(0xFFF0F2F5);

  static const domainColors = <String, Color>{
    'finance': Color(0xFF1B5E20),
    'politics': Color(0xFF880E4F),
    'ai_tech': Color(0xFF0D47A1),
    'law': Color(0xFF4A148C),
    'health': Color(0xFF004D40),
    'fashion': Color(0xFFBF360C),
    'dharma': Color(0xFFE65100),
  };

  static Color forDomain(String domain) => domainColors[domain] ?? primary;
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.divider),
          ),
          margin: EdgeInsets.zero,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.accent, width: 3),
          ),
          indicatorSize: TabBarIndicatorSize.label,
        ),
        textTheme: const TextTheme(
          displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: AppColors.textPrimary),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.3),
          bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.75, color: AppColors.textPrimary),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
          labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: AppColors.textSecondary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputFill,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        splashFactory: InkRipple.splashFactory,
        highlightColor: Colors.transparent,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      );
}
