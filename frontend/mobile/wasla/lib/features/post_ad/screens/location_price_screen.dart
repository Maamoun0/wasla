import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class LocationPriceScreen extends StatelessWidget {
  const LocationPriceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الموقع والسعر')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_rounded, size: 64, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text('الموقع والسعر', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
