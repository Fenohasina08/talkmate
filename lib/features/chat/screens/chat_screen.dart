import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(AppStrings.myConversations),
      ),
    );
  }
}
