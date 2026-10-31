import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/core/router/app_router.dart';
import 'package:wasla/features/notifications/providers/notifications_provider.dart';

void main() {
  group('notificationRoute (push taps and the in-app list)', () {
    test('a saved-search match opens the ad', () {
      expect(notificationRoute({'type': 'watchlist_match', 'ad_id': 'abc'}), '/ad/abc');
    });

    test('an approval or rejection opens My Ads', () {
      expect(notificationRoute({'type': 'ad_status_change', 'ad_id': 'abc'}), AppRoutes.myAds);
    });

    test('unknown or incomplete payloads open nothing', () {
      expect(notificationRoute(null), isNull);
      expect(notificationRoute({'type': 'watchlist_match'}), isNull);
      expect(notificationRoute({'type': 'something_new'}), isNull);
    });
  });

  test('relative times in Arabic', () {
    final now = DateTime(2026, 10, 31, 12);
    expect(relativeTimeAr(now.subtract(const Duration(seconds: 20)), now: now), 'الآن');
    expect(relativeTimeAr(now.subtract(const Duration(minutes: 1)), now: now), 'منذ دقيقة');
    expect(relativeTimeAr(now.subtract(const Duration(minutes: 2)), now: now), 'منذ دقيقتين');
    expect(relativeTimeAr(now.subtract(const Duration(minutes: 5)), now: now), 'منذ 5 دقائق');
    expect(relativeTimeAr(now.subtract(const Duration(minutes: 25)), now: now), 'منذ 25 دقيقة');
    expect(relativeTimeAr(now.subtract(const Duration(hours: 3)), now: now), 'منذ 3 ساعات');
    expect(relativeTimeAr(now.subtract(const Duration(days: 2)), now: now), 'منذ يومين');
    expect(relativeTimeAr(now.subtract(const Duration(days: 1)), now: now), 'أمس');
    expect(relativeTimeAr(now.subtract(const Duration(days: 4)), now: now), 'منذ 4 أيام');
    expect(relativeTimeAr(DateTime(2026, 9, 2, 12), now: now), '2/9/2026');
  });
}
