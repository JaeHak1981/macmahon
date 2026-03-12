import 'package:flutter/material.dart';

class AppTheme {
  // ── 색상 팔레트 ──────────────────────────────────
  static const Color primary = Color(0xFF1B5E20);       // 바둑판 짙은 녹색
  static const Color primaryLight = Color(0xFF388E3C);
  static const Color primaryDark = Color(0xFF003300);
  static const Color accent = Color(0xFFFFD54F);        // 금색 강조
  static const Color surface = Color(0xFFFAF7F0);       // 따뜻한 흰색
  static const Color background = Color(0xFFF0EBE0);    // 바둑판 배경
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF5C5C5C);
  static const Color black = Color(0xFF212121);         // 흑돌
  static const Color white = Color(0xFFF5F5F5);         // 백돌
  static const Color floatDown = Color(0xFFE53935);     // Float Down 빨강
  static const Color floatUp = Color(0xFF1976D2);       // Float Up 파랑
  static const Color byeColor = Color(0xFF9E9E9E);      // 부전승 회색

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: primary,
          onPrimary: Colors.white,
          secondary: accent,
          onSecondary: Colors.black,
          error: Colors.red,
          onError: Colors.white,
          surface: surface,
          onSurface: textPrimary,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
        cardTheme: CardThemeData(
          color: cardBg,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.grey.shade200,
          selectedColor: primaryLight,
          labelStyle: const TextStyle(fontSize: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFDDD8CC),
          thickness: 1,
          space: 1,
        ),
      );
}
