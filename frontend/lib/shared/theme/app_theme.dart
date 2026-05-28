import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _bg = Color(0xFF111318);
const _surface = Color(0xFF1C1F26);
const _surfaceRaised = Color(0xFF23262F);
const _border = Color(0xFF2A2D35);

class AppColors {
  static const primary = Color(0xFF1A237E);
  static const accent = Color(0xFFFF6F00);

  static const background = _bg;
  static const surface = _surface;
  static const surfaceRaised = _surfaceRaised;

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xCCFFFFFF);
  static const textMuted = Color(0x77FFFFFF);
  static const divider = _border;
  static const inputFill = _surfaceRaised;

  static const domainColors = <String, Color>{
    'finance':  Color(0xFF2E7D32),
    'politics': Color(0xFFAD1457),
    'ai_tech':  Color(0xFF1565C0),
    'law':      Color(0xFF6A1B9A),
    'health':   Color(0xFF00695C),
    'fashion':  Color(0xFFD84315),
    'dharma':   Color(0xFFEF6C00),
  };

  static Color forDomain(String domain) => domainColors[domain] ?? primary;
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          surface: _surface,
        ),
        scaffoldBackgroundColor: _bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: _surface,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _border),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(color: _border, space: 1),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Color(0x88FFFFFF),
          labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 13),
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.accent, width: 2),
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
          labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Color(0x77FFFFFF)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surfaceRaised,
          hintStyle: const TextStyle(color: Color(0x55FFFFFF)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: _border),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: _border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      );
}
