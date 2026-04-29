import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_theme.dart';
import 'services/security_service.dart';
import 'screens/lock_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MacmahonApp(),
    ),
  );
}

class MacmahonApp extends StatelessWidget {
  const MacmahonApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 만료 여부 확인
    final isExpired = SecurityService.isExpired();

    return MaterialApp(
      title: '맥마흔 시스템',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
      ],
      home: isExpired ? const LockScreen() : const HomeScreen(),
    );
  }
}
