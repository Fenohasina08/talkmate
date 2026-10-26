import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text(AppStrings.learnLanguage)));
  }
}
