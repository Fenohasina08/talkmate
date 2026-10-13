import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(AppStrings.myFriends),
      ),
    );
  }
}
