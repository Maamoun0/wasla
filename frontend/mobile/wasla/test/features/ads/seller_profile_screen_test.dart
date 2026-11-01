import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/features/ads/screens/seller_profile_screen.dart';

import '../../helpers/fake_backend.dart';

FakeBackend _seller({bool profileFails = false}) => FakeBackend({
      '/rest/v1/users': (_) => profileFails
          ? const Failure(500)
          : {
              'id': 's1',
              'full_name': 'أحمد البائع',
              'bio': 'بيع وشراء عربيات',
              'trust_score': 80,
              'is_id_verified': true,
              'created_at': '2025-01-15T10:00:00Z',
            },
      '/rest/v1/ads': (_) => [
            {
              'id': 'a1',
              'title': 'عربية للبيع',
              'price': 250000,
              'price_type': 'fixed',
              'is_featured': true,
              'is_urgent': true,
              'created_at': '2026-10-01T10:00:00Z',
              'cities': {'name_ar': 'المعادي'},
              'ad_media': [],
            },
            {'id': 'a2', 'title': 'هدية', 'price': 0, 'price_type': 'free', 'created_at': '2026-10-02T10:00:00Z'},
          ],
      '/rest/v1/reviews': (_) => [
            {
              'id': 'r1',
              'rating': 5,
              'comment': 'بائع محترم',
              'created_at': '2026-10-05T10:00:00Z',
              'reviewer': {'full_name': 'منى'},
              'review_responses': [
                {'response': 'شكراً', 'created_at': '2026-10-06T10:00:00Z'}
              ],
            },
          ],
    });

void main() {
  testWidgets('shows the seller, their active ads and reviews, and opens an ad', (tester) async {
    final backend = _seller();
    final nav = NavProbe();
    await pumpScreen(tester, const SellerProfileScreen(userId: 's1'), backend: backend, nav: nav);

    expect(find.text('أحمد البائع'), findsOneWidget);
    expect(find.text('بيع وشراء عربيات'), findsOneWidget);
    expect(find.text('الإعلانات (2)'), findsOneWidget);
    expect(find.text('التقييمات (1)'), findsOneWidget);
    expect(find.text('عربية للبيع'), findsOneWidget);
    expect(find.text('250,000 ج.م'), findsOneWidget);
    expect(find.text('مجاناً'), findsOneWidget);
    expect(find.text('مميز'), findsOneWidget);
    // Only this seller's active ads are asked for.
    final adsQuery = backend.to('/rest/v1/ads').single.url.queryParameters;
    expect([adsQuery['user_id'], adsQuery['status']], ['eq.s1', 'eq.active']);

    await tester.tap(find.text('التقييمات (1)'));
    await tester.pumpAndSettle();
    expect(find.text('بائع محترم'), findsOneWidget);
    expect(find.text('رد المعلن:'), findsOneWidget);
    expect(find.text('شكراً'), findsOneWidget);

    await tester.tap(find.text('الإعلانات (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عربية للبيع'));
    await tester.pumpAndSettle();
    expect(nav.location, '/ad/a1');
  });

  testWidgets('a seller with nothing yet shows the empty states', (tester) async {
    final backend = _seller()
      ..routes['/rest/v1/ads'] = ((_) => const [])
      ..routes['/rest/v1/reviews'] = ((_) => const []);
    await pumpScreen(tester, const SellerProfileScreen(userId: 's1'), backend: backend);

    expect(find.text('لا توجد إعلانات نشطة حالياً لهذا المعلن.'), findsOneWidget);
    await tester.tap(find.text('التقييمات (0)'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد تقييمات لهذا المعلن بعد.'), findsOneWidget);
  });

  testWidgets('a failed profile load offers a retry that asks again', (tester) async {
    final backend = _seller(profileFails: true);
    await pumpScreen(tester, const SellerProfileScreen(userId: 's1'), backend: backend);

    expect(find.text('فشل تحميل الملف الشخصي للمعلن'), findsOneWidget);
    final before = backend.to('/rest/v1/users').length;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(backend.to('/rest/v1/users').length, greaterThan(before));
  });
}
