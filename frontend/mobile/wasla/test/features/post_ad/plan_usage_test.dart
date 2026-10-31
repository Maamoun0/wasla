import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/features/post_ad/providers/plan_usage_provider.dart';

void main() {
  test('reads my_plan_usage as returned by the server', () {
    final u = PlanUsage.fromJson({'plan': 'free', 'plan_name_ar': 'مجاني', 'max_ads': 5, 'max_images_per_ad': 4, 'live_ads': 5});
    expect([u.plan, u.maxAds, u.maxImagesPerAd, u.liveAds], ['free', 5, 4, 5]);
    expect(u.atAdLimit, isTrue);
    expect(u.adLimitMessage, contains('مجاني'));
    expect(u.adLimitMessage, contains('5'));
  });

  test('below the limit the user can post', () {
    expect(PlanUsage.fromJson({'max_ads': 20, 'live_ads': 3}).atAdLimit, isFalse);
  });

  test('the fallback photo limit is the smallest plan\'s', () {
    expect(fallbackMaxImages, 8);
  });
}
