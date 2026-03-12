import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
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
    return MaterialApp(
      title: '맥마흔 시스템',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const HomeScreen(),
    );
  }
}
