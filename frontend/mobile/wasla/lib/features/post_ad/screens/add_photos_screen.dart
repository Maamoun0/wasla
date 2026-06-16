import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AddPhotosScreen extends StatelessWidget {
  const AddPhotosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة الصور')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded, size: 64, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text('إضافة الصور', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
