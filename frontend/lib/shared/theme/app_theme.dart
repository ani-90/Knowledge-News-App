import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const primary = Color(0xFF1A237E);
  static const primaryLight = Color(0xFF283593);
  static const accent = Color(0xFFFF6F00);

  // Glass palette — used for text on dark gradient backgrounds
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xCCFFFFFF); // white 80%
  static const textMuted = Color(0x99FFFFFF);     // white 60%
  static const divider = Color(0x33FFFFFF);       // white 20%
  static const inputFill = Color(0x22FFFFFF);     // white 13%

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

class AppGradients {
  static const background = LinearGradient(
    colors: [Color(0xFF0D1117), Color(0xFF161B27), Color(0xFF0D1117)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
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
          color: Colors.white.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
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
          displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Colors.white),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3),
          bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.75, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xCCFFFFFF)),
          labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Color(0x99FFFFFF)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.10),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
        splashFactory: InkRipple.splashFactory,
        highlightColor: Colors.transparent,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      );
}
