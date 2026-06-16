import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AdPreviewScreen extends StatelessWidget {
  const AdPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('معاينة الإعلان')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.preview_rounded, size: 64, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text('معاينة الإعلان', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
