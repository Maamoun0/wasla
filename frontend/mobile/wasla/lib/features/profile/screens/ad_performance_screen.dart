import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AdPerformanceScreen extends StatelessWidget {
  const AdPerformanceScreen({super.key, required this.adId});
  final String adId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أداء الإعلان')),
      body: const Center(
        child: Icon(Icons.bar_chart_rounded, size: 64, color: AppColors.neutral300),
      ),
    );
  }
}
