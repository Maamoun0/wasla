import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class TrustBadge extends StatelessWidget {
  final double trustScore; // Scale 0-100
  final bool isVerified;
  final double? fontSize;
  final double? iconSize;

  const TrustBadge({
    super.key,
    required this.trustScore,
    required this.isVerified,
    this.fontSize,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String badgeText;
    
    if (trustScore >= 70.0) {
      badgeColor = const Color(0xFFD4AF37); // Warm Gold
      badgeText = 'موثوق جداً';
    } else if (trustScore >= 40.0) {
      badgeColor = const Color(0xFF0D9488); // Teal
      badgeText = 'موثوق';
    } else {
      badgeColor = AppColors.neutral500; // Grey
      badgeText = 'جديد';
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Trust Score Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: badgeColor.withOpacity(0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_rounded,
                color: badgeColor,
                size: iconSize ?? 14,
              ),
              const SizedBox(width: 4),
              Text(
                '$badgeText (${trustScore.toStringAsFixed(0)}%)',
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize ?? 11,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),

        // Separate checkmark verified badge if isVerified is true
        if (isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.success.withOpacity(0.4), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: AppColors.success,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'حساب مؤكد',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize ?? 11,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
