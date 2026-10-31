import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';

/// How many notifications the center shows (newest first).
const notificationsPageSize = 50;

/// Where a notification leads, from its `data` payload. Shared by push taps
/// and the in-app list. Null: nothing to open.
String? notificationRoute(Map<String, dynamic>? data) {
  if (data == null) return null;
  final adId = data['ad_id'];
  switch (data['type']) {
    case 'watchlist_match':
      return adId is String && adId.isNotEmpty ? '/ad/$adId' : null;
    case 'ad_status_change':
      return AppRoutes.myAds;
    default:
      return null;
  }
}

/// Arabic count + noun: 1 دقيقة, 2 دقيقتين, 3–10 دقائق, 11+ دقيقة.
String _arabicCount(int n, String one, String two, String few) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n <= 10) return '$n $few';
  return '$n $one';
}

/// "منذ 5 دقائق" style time for the list.
String relativeTimeAr(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${_arabicCount(diff.inMinutes, 'دقيقة', 'دقيقتين', 'دقائق')}';
  if (diff.inHours < 24) return 'منذ ${_arabicCount(diff.inHours, 'ساعة', 'ساعتين', 'ساعات')}';
  if (diff.inDays == 1) return 'أمس';
  if (diff.inDays < 7) return 'منذ ${_arabicCount(diff.inDays, 'يوم', 'يومين', 'أيام')}';
  final local = time.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

/// Live list (realtime publication), newest first, capped.
final notificationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(supabaseClientProvider)
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(notificationsPageSize)
      .map((rows) => rows.cast<Map<String, dynamic>>());
});

/// Badge count from the server, refreshed whenever the live list changes.
final unreadCountProvider = FutureProvider<int>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return 0;
  ref.watch(notificationsProvider);
  final count = await ref.watch(supabaseClientProvider).rpc<int>('unread_notifications_count');
  return count;
});
