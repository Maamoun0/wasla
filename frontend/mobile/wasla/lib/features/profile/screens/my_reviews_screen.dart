import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class MyReviewsScreen extends StatelessWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقييماتي')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_rounded, size: 64, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text('تقييماتي', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
