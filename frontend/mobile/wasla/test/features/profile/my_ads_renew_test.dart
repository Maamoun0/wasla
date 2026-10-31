import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/features/profile/providers/my_ads_provider.dart';

void main() {
  final now = DateTime(2026, 10, 31, 12);

  group('canRenewAd (same rule as renew_ad)', () {
    test('expired ads can always be renewed', () {
      expect(canRenewAd('expired', null, now: now), isTrue);
    });

    test('active ads only in their last 3 days', () {
      expect(canRenewAd('active', now.add(const Duration(days: 2)), now: now), isTrue);
      expect(canRenewAd('active', now.add(const Duration(days: 3)), now: now), isTrue, reason: 'the boundary is included');
      expect(canRenewAd('active', now.add(const Duration(days: 3, minutes: 1)), now: now), isFalse);
      expect(canRenewAd('active', now.add(const Duration(days: 20)), now: now), isFalse);
    });

    test('pending, rejected and sold ads cannot be renewed', () {
      for (final s in ['pending', 'rejected', 'sold', 'paused']) {
        expect(canRenewAd(s, now, now: now), isFalse, reason: s);
      }
    });
  });

  test('expiry text for active ads', () {
    expect(expiryLabel('active', now.add(const Duration(hours: 5)), now: now), 'ينتهي اليوم');
    expect(expiryLabel('active', now.add(const Duration(days: 1, hours: 2)), now: now), 'ينتهي بكرة');
    expect(expiryLabel('active', now.add(const Duration(days: 2, hours: 2)), now: now), 'ينتهي خلال يومين');
    expect(expiryLabel('active', now.add(const Duration(days: 6)), now: now), 'ينتهي خلال 6 أيام');
    expect(expiryLabel('active', now.add(const Duration(days: 25)), now: now), 'ينتهي خلال 25 يوم');
    expect(expiryLabel('expired', now, now: now), isNull);
  });
}
