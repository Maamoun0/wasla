import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/post_ad_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// The caller's plan limits and usage (my_plan_usage). The server enforces
/// them again on publish; the app uses them to warn early.
class PlanUsage {
  const PlanUsage({
    required this.plan,
    required this.planNameAr,
    required this.maxAds,
    required this.maxImagesPerAd,
    required this.liveAds,
  });

  final String plan;
  final String planNameAr;
  final int maxAds;
  final int maxImagesPerAd;
  /// Pending + active ads.
  final int liveAds;

  bool get atAdLimit => liveAds >= maxAds;

  factory PlanUsage.fromJson(Map<String, dynamic> j) => PlanUsage(
        plan: j['plan'] as String? ?? 'free',
        planNameAr: j['plan_name_ar'] as String? ?? '',
        maxAds: (j['max_ads'] as num?)?.toInt() ?? 0,
        maxImagesPerAd: (j['max_images_per_ad'] as num?)?.toInt() ?? 0,
        liveAds: (j['live_ads'] as num?)?.toInt() ?? 0,
      );

  String get adLimitMessage =>
      'وصلت للحد الأقصى لباقة "$planNameAr" ($maxAds إعلانات نشطة أو قيد المراجعة). احذف إعلاناً أو رقِّ باقتك عشان تنشر.';
}

/// Photo limit used while the plan is loading or unavailable: the smallest
/// plan's, so the app never promises more than the server accepts.
const fallbackMaxImages = 8;

final planUsageProvider = FutureProvider.autoDispose<PlanUsage?>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return null;
  final res = await ref.watch(postAdRepositoryProvider).planUsage();
  return res is Map ? PlanUsage.fromJson(res.cast<String, dynamic>()) : null;
});
