import 'package:flutter/material.dart';

class AppTheme {
  // ── 색상 팔레트 ──────────────────────────────────
  static const Color primary = Color(
    0xFF4A6572,
  ); // 부드러운 더스티 블루 (차분하고 따뜻한 네이비 계열)
  static const Color primaryLight = Color(0xFF7A94A1); // 옅은 스모키 블루
  static const Color primaryDark = Color(0xFF233C48); // 깊고 차분한 다크 블루
  static const Color accent = Color(0xFFF9A826); // 따뜻하고 친근한 머스터드 옐로우 액센트
  static const Color surface = Color(0xFFFFFFFF); // 기분 좋은 순백색
  static const Color background = Color(
    0xFFF7F5F0,
  ); // 따뜻한 아이보리(크림) 화이트 배경 (편안함 제공)
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(
    0xFF3E4A59,
  ); // 흑백 대신 많이 부드러워진 다크 그레이-블루 텍스트
  static const Color textSecondary = Color(0xFF909CA6); // 포근한 안내 문구 회색
  static const Color black = Color(0xFF2C3E50); // 흑돌 (부드럽고 따뜻한 딥 차콜)
  static const Color white = Color(0xFFFCFDFD); // 백돌 (맑은 도자기 화이트)
  static const Color floatDown = Color(0xFFF06292); // 경고/마이너스를 부드러운 파스텔 핑크로
  static const Color floatUp = Color(0xFF4FC3F7); // 상향/플러스를 부드러운 파스텔 스카이블루로
  static const Color byeColor = Color(0xFFB0BEC5); // 따뜻한 은회색

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
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      iconTheme: const IconThemeData(color: Color(0xFF2C3E50)),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF2C3E50),
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0.5,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey.shade200,
      selectedColor: primaryLight,
      labelStyle: const TextStyle(fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFDDD8CC),
      thickness: 1,
      space: 1,
    ),
  );
}
