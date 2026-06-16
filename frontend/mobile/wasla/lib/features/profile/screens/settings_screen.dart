import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings_rounded, size: 64, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text('الإعدادات', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
