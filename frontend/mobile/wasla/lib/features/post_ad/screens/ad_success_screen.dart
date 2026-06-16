import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AdSuccessScreen extends StatelessWidget {
  const AdSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تم النشر')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, size: 64, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text('تم النشر', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
