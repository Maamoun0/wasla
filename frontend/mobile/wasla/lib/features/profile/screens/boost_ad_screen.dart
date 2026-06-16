import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class BoostAdScreen extends StatelessWidget {
  const BoostAdScreen({super.key, required this.adId});
  final String adId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعزيز الإعلان')),
      body: const Center(
        child: Icon(Icons.flash_on_rounded, size: 64, color: AppColors.accent500),
      ),
    );
  }
}
