import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اشتراكي')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.workspace_premium_outlined, size: 64, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text('اشتراكي', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
