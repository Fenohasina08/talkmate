import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/home/home_screen.dart';

class TalkMateApp extends StatelessWidget {
  const TalkMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TalkMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}