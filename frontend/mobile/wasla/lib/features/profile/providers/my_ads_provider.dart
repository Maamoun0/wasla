import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

/// Owners may renew an expired ad, or an active one in its last 3 days
/// (same rule as renew_ad on the server).
const renewWindow = Duration(days: 3);

bool canRenewAd(String status, DateTime? expiresAt, {DateTime? now}) {
  if (status == 'expired') return true;
  if (status != 'active' || expiresAt == null) return false;
  return !expiresAt.isAfter((now ?? DateTime.now()).add(renewWindow));
}

/// "ينتهي اليوم" / "ينتهي بكرة" / "ينتهي خلال 5 أيام" for an active ad.
String? expiryLabel(String status, DateTime? expiresAt, {DateTime? now}) {
  if (status != 'active' || expiresAt == null) return null;
  final days = expiresAt.difference(now ?? DateTime.now()).inHours ~/ 24;
  if (days <= 0) return 'ينتهي اليوم';
  if (days == 1) return 'ينتهي بكرة';
  if (days == 2) return 'ينتهي خلال يومين';
  if (days <= 10) return 'ينتهي خلال $days أيام';
  return 'ينتهي خلال $days يوم';
}

/// The owner's ads in one status, newest first.
final myAdsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, status) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  final rows = await ref.watch(supabaseClientProvider).from('ads').select('''
        id, title, price, price_type, views_count, contacts_count, favorites_count,
        created_at, expires_at, rejection_reason, is_featured,
        ad_media(url, is_primary),
        cities(name_ar)
      ''').eq('user_id', uid).eq('status', status).order('created_at', ascending: false);
  return rows.cast<Map<String, dynamic>>();
});

/// Renews an ad through renew_ad. Returns null on success, else a message.
Future<String?> renewAd(Ref ref, String adId) async {
  final res = await ref.read(supabaseClientProvider).rpc('renew_ad', params: {'p_ad_id': adId});
  final map = res is Map ? res : const {};
  if (map['success'] == true) {
    ref.invalidate(myAdsProvider);
    return null;
  }
  return map['error'] == 'not_renewable'
      ? 'الإعلان ده لسه مش محتاج تجديد. تقدر تجدده في آخر 3 أيام من مدته.'
      : 'تعذّر تجديد الإعلان. حاول مرة أخرى.';
}

final renewAdProvider = Provider<Future<String?> Function(String adId)>((ref) => (adId) => renewAd(ref, adId));
