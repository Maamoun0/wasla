import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_rounded, size: 64, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text('الإشعارات', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
