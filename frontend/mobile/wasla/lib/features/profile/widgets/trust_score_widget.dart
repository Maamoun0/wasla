import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TrustScoreWidget extends StatelessWidget {
  final double score; // 0 to 100
  final bool isLarge;

  const TrustScoreWidget({
    super.key,
    required this.score,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    Color scoreColor;
    String rank;

    if (score >= 80) {
      scoreColor = AppColors.success;
      rank = 'موثوق جداً';
    } else if (score >= 50) {
      scoreColor = AppColors.warning;
      rank = 'متوسط الموثوقية';
    } else {
      scoreColor = AppColors.error;
      rank = 'تحت المراجعة';
    }

    return Container(
      padding: EdgeInsets.all(isLarge ? 16 : 8),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_rounded,
                color: scoreColor,
                size: isLarge ? 24 : 16,
              ),
              const SizedBox(width: 8),
              Text(
                'نقاط الثقة: ${score.toInt()}/100',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: isLarge ? 16 : 12,
                  color: scoreColor,
                ),
              ),
            ],
          ),
          if (isLarge) ...[
            const SizedBox(height: 4),
            Text(
              rank,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: scoreColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: score / 100,
              backgroundColor: scoreColor.withOpacity(0.2),
              color: scoreColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ],
      ),
    );
  }
}
