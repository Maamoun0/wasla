import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class SellerProfileScreen extends StatelessWidget {
  const SellerProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ملف المعلن')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_rounded, size: 64, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text('ملف المعلن: $userId', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
