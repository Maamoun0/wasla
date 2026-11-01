import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/data/repositories/auth_repository.dart';
import 'package:wasla/features/auth/providers/auth_provider.dart';
import 'package:wasla/features/profile/screens/my_ads_screen.dart';
import 'package:wasla/features/profile/screens/profile_screen.dart';

import '../../helpers/fake_backend.dart';

String _inDays(int days) => DateTime.now().add(Duration(days: days)).toIso8601String();

FakeBackend _myAds() => FakeBackend({
      'GET /rest/v1/ads': (req) => switch (req.url.queryParameters['status']) {
            'eq.active' => [
                {
                  'id': 'a1',
                  'title': 'لابتوب ديل',
                  'price': 15000,
                  'views_count': 40,
                  'contacts_count': 3,
                  'favorites_count': 5,
                  'expires_at': _inDays(2),
                  'is_featured': true,
                },
              ],
            'eq.rejected' => [
                {'id': 'a2', 'title': 'موبايل', 'rejection_reason': 'صور مش واضحة', 'expires_at': _inDays(20)},
              ],
            _ => const [],
          },
      '/rest/v1/rpc/renew_ad': (_) => {'success': true},
      '/rest/v1/app_configs': (_) => const [],
    });

class _RecordingAuth extends AuthNotifier {
  _RecordingAuth()
      : super(AuthRepository(SupabaseClient('http://localhost:1', 'k', authOptions: const AuthClientOptions(autoRefreshToken: false))));
  int signOuts = 0;
  @override
  Future<void> signOut() async => signOuts++;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('my ads', () {
    testWidgets('shows each status tab with its ads, stats and actions', (tester) async {
      final backend = _myAds();
      final nav = NavProbe();
      await pumpScreen(tester, const MyAdsScreen(), backend: backend, nav: nav);

      expect(find.text('لابتوب ديل'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      // Only the signed-in user's ads.
      expect(backend.to('/rest/v1/ads').first.url.queryParameters['user_id'], 'eq.u1');

      // Expires in 2 days: renewable.
      await tester.tap(find.text('تجديد'));
      await tester.pumpAndSettle();
      expect(backend.lastBody('/rest/v1/rpc/renew_ad'), {'p_ad_id': 'a1'});
      expect(find.text('تم تجديد الإعلان لمدة 30 يوم.'), findsOneWidget);

      await tester.tap(find.text('rejectedStatusFem'));
      await tester.pumpAndSettle();
      expect(find.text('موبايل'), findsOneWidget);
      expect(find.textContaining('صور مش واضحة'), findsOneWidget);

      await tester.tap(find.text('pending'));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('a refused renewal shows why', (tester) async {
      final backend = _myAds()..routes['/rest/v1/rpc/renew_ad'] = (_) => {'success': false, 'error': 'not_renewable'};
      await pumpScreen(tester, const MyAdsScreen(), backend: backend);

      await tester.tap(find.text('تجديد'));
      await tester.pumpAndSettle();
      expect(find.textContaining('مش محتاج تجديد'), findsOneWidget);
    });

    testWidgets('"new ad" opens the posting flow', (tester) async {
      final nav = NavProbe();
      await pumpScreen(tester, const MyAdsScreen(), backend: _myAds(), nav: nav);
      await tester.tap(find.text('newAd'));
      await tester.pumpAndSettle();
      expect(nav.location, '/post/category');
    });
  });

  group('profile', () {
    testWidgets('a guest sees the sign-in prompt', (tester) async {
      final nav = NavProbe();
      await pumpScreen(tester, const ProfileScreen(), backend: FakeBackend(), userId: null, nav: nav);

      await tester.tap(find.text('login'));
      await tester.pumpAndSettle();
      expect(nav.location, startsWith('/auth'));
    });

    testWidgets('a signed-in user sees their name and menu, and can sign out', (tester) async {
      final auth = _RecordingAuth();
      final backend = FakeBackend({
        '/rest/v1/rpc/get_my_profile': (_) => {'id': 'u1', 'full_name': 'سارة علي', 'user_type': 'business', 'is_id_verified': false},
        '/rest/v1/app_configs': (_) => const [],
      });
      final nav = NavProbe();
      await pumpScreen(tester, const ProfileScreen(), backend: backend, nav: nav,
          overrides: [authNotifierProvider.overrideWith((ref) => auth)]);

      expect(find.text('سارة علي'), findsOneWidget);
      expect(find.text('verifyAccountMsg'), findsOneWidget);
      for (final item in ['myAds', 'favorites', 'mySubscription', 'myReviews', 'settings']) {
        expect(find.text(item), findsWidgets, reason: item);
      }

      await tester.tap(find.text('logout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('exit'));
      await tester.pumpAndSettle();
      expect(auth.signOuts, 1);
      expect(nav.location, '/auth');
    });

    testWidgets('menu items open their pages', (tester) async {
      final backend = FakeBackend({
        '/rest/v1/rpc/get_my_profile': (_) => {'id': 'u1', 'full_name': 'سارة'},
      });
      final nav = NavProbe();
      await pumpScreen(tester, const ProfileScreen(), backend: backend, nav: nav);

      await tester.tap(find.text('myReviews'));
      await tester.pumpAndSettle();
      expect(nav.location, '/profile/reviews');
    });
  });
}
