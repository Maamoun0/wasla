import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحقق من الهوية')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_rounded, size: 64, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text('التحقق من الهوية', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
