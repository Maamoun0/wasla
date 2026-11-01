import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/features/profile/screens/boost_ad_screen.dart';
import 'package:wasla/features/profile/screens/subscription_screen.dart';

import '../../helpers/fake_backend.dart';

final _plans = [
  {
    'id': 1,
    'name': 'free',
    'name_ar': 'مجانية',
    'max_ads': 5,
    'max_images_per_ad': 8,
    'features': <String, dynamic>{},
    'payment_packages': <Map<String, dynamic>>[],
  },
  {
    'id': 2,
    'name': 'business',
    'name_ar': 'أعمال',
    'max_ads': 999,
    'max_images_per_ad': 15,
    'features': {'boost': true, 'analytics': true},
    'payment_packages': [
      {'id': 'pkg-biz-30', 'price_egp': 499, 'duration_days': 30},
      {'id': 'pkg-biz-365', 'price_egp': 4990, 'duration_days': 365},
    ],
  },
];

FakeBackend _payments({Object? activeSubscription, Object? Function()? payment}) => FakeBackend({
      '/rest/v1/subscription_plans': (_) => _plans,
      '/rest/v1/user_subscriptions': (_) => activeSubscription,
      'GET /rest/v1/ads': (req) => req.url.queryParameters.containsKey('user_id')
          ? [
              {'id': 'ad1', 'title': 'شقة للإيجار', 'ad_boosts': []},
              {
                'id': 'ad2',
                'title': 'عربية متروّجة',
                'ad_boosts': [
                  {'expires_at': DateTime.now().add(const Duration(days: 3)).toIso8601String(), 'boost_type': 'featured'}
                ],
              },
            ]
          : {'id': 'ad1', 'status': 'active', 'ad_boosts': []},
      '/rest/v1/payment_packages': (_) => [
            {'id': 'boost-featured-7', 'name_ar': 'مميز 7 أيام', 'price_egp': 50, 'boost_type': 'featured', 'duration_days': 7},
            {'id': 'boost-urgent-3', 'name_ar': 'عاجل 3 أيام', 'price_egp': 20, 'boost_type': 'urgent', 'duration_days': 3},
          ],
      '/functions/v1/create-payment': (_) =>
          payment?.call() ?? {'payment_url': 'https://accept.paymob.test/iframe/1', 'transaction_id': 77},
    });

void main() {
  group('subscriptions', () {
    testWidgets('lists the plans; the free plan is current when there is no subscription', (tester) async {
      await pumpScreen(tester, const SubscriptionScreen(), backend: _payments());

      expect(find.text('مجانية'), findsOneWidget);
      expect(find.text('أعمال'), findsOneWidget);
      expect(find.text('499'), findsOneWidget, reason: 'the monthly package price');
      expect(find.text('الحد الأقصى للإعلانات النشطة: غير محدود'), findsOneWidget);
      expect(find.text('الصور لكل إعلان: 15 صور'), findsOneWidget);
      expect(find.text('هذه باقتك الحالية'), findsOneWidget);
    });

    testWidgets('subscribing charges the monthly package and opens the payment page', (tester) async {
      final backend = _payments();
      final nav = NavProbe();
      await pumpScreen(tester, const SubscriptionScreen(), backend: backend, nav: nav);

      await tapAndWait(tester, find.text('اشتراك الآن'));

      expect(backend.lastBody('/functions/v1/create-payment'), {'package_id': 'pkg-biz-30'});
      expect(nav.location, '/profile/payment');
    });

    testWidgets('switching from a paid plan warns that the remaining time is not refunded', (tester) async {
      final backend = _payments(activeSubscription: {
        'plan_id': 2,
        'expires_at': '2026-12-01T00:00:00Z',
        'subscription_plans': {'name': 'business', 'name_ar': 'أعمال'},
      });
      await pumpScreen(tester, const SubscriptionScreen(), backend: backend);

      expect(find.text('باقتك الحالية: أعمال'), findsOneWidget);
      await tester.tap(find.text('الرجوع للمجاني'));
      await tester.pumpAndSettle();
      expect(find.text('تغيير باقة الاشتراك'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(backend.to('/functions/v1/create-payment'), isEmpty);
    });

    testWidgets('a refused payment shows the server message', (tester) async {
      final backend = _payments(payment: () => const Failure(409, 'عندك اشتراك فعّال'));
      await pumpScreen(tester, const SubscriptionScreen(), backend: backend);

      await tapAndWait(tester, find.text('اشتراك الآن'));
      expect(find.text('عندك اشتراك فعّال'), findsOneWidget);
    });
  });

  group('boost', () {
    testWidgets('offers only ads without a running boost, and pays for the chosen package', (tester) async {
      final backend = _payments();
      final nav = NavProbe();
      await pumpScreen(tester, const BoostAdScreen(adId: 'ad1'), backend: backend, nav: nav);

      // ad1 is preselected from the route; ad2 already has a boost running.
      expect(find.text('شقة للإيجار'), findsWidgets);
      expect(find.text('عربية متروّجة'), findsNothing);
      expect(find.text('مميز 7 أيام'), findsOneWidget);
      expect(find.text('عاجل 3 أيام'), findsOneWidget);

      await tester.tap(find.text('عاجل 3 أيام'));
      await tester.pumpAndSettle();
      expect(find.text('إجمالي المبلغ المطلوب دفعه:'), findsOneWidget);
      expect(find.text('20 ج.م'), findsWidgets);

      await tapAndWait(tester, find.text('أكمل الدفع الآمن مع Paymob'));
      expect(backend.lastBody('/functions/v1/create-payment'), {'package_id': 'boost-urgent-3', 'ad_id': 'ad1'});
      expect(nav.location, '/profile/payment');
    });

    testWidgets('an ad that stopped being active is not charged', (tester) async {
      final backend = _payments()
        ..routes['GET /rest/v1/ads'] = (req) => req.url.queryParameters.containsKey('user_id')
            ? [
                {'id': 'ad1', 'title': 'شقة للإيجار', 'ad_boosts': []}
              ]
            : {'id': 'ad1', 'status': 'expired', 'ad_boosts': []};
      await pumpScreen(tester, const BoostAdScreen(adId: 'ad1'), backend: backend);

      await tester.tap(find.text('مميز 7 أيام'));
      await tester.pumpAndSettle();
      await tapAndWait(tester, find.text('أكمل الدفع الآمن مع Paymob'));

      expect(find.text('عذراً، لا يمكن ترويج هذا الإعلان لأنه غير نشط حالياً'), findsOneWidget);
      expect(backend.to('/functions/v1/create-payment'), isEmpty);
    });

    testWidgets('no eligible ads: says so', (tester) async {
      final backend = _payments()..routes['GET /rest/v1/ads'] = (_) => const [];
      await pumpScreen(tester, const BoostAdScreen(adId: 'all'), backend: backend);
      expect(find.text('ليس لديك أي إعلانات نشطة مؤهلة للترقية حالياً.'), findsOneWidget);
    });
  });
}
