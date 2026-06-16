import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({super.key, required this.adId, this.initialIndex = 0});
  final String adId;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: const Center(
        child: Icon(Icons.photo_library_rounded, size: 64, color: AppColors.neutral500),
      ),
    );
  }
}
