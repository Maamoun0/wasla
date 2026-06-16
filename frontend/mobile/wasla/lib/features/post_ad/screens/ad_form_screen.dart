import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AdFormScreen extends StatelessWidget {
  const AdFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الإعلان')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_rounded, size: 64, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text('تفاصيل الإعلان', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
