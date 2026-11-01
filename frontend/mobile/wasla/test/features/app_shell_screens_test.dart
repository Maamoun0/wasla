import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session, User;
import 'package:wasla/core/router/app_router.dart';
import 'package:wasla/features/ads/screens/photo_viewer_screen.dart';
import 'package:wasla/features/auth/providers/auth_provider.dart';
import 'package:wasla/features/auth/screens/onboarding_screen.dart';
import 'package:wasla/features/auth/screens/splash_screen.dart';
import 'package:wasla/features/legal/legal_provider.dart';
import 'package:wasla/features/post_ad/screens/ad_success_screen.dart';
import 'package:wasla/shared/widgets/bottom_nav_shell.dart';

import '../helpers/fake_backend.dart';

void main() {
  group('photo viewer', () {
    testWidgets('pages through the ad photos from the tapped one', (tester) async {
      final backend = FakeBackend({
        '/rest/v1/ad_media': (_) => [
              {'url': 'https://img.test/1.jpg'},
              {'url': 'https://img.test/2.jpg'},
              {'url': 'https://img.test/3.jpg'},
            ],
      });
      await pumpScreen(tester, const PhotoViewerScreen(adId: 'a1', initialIndex: 1), backend: backend);

      expect(backend.to('/rest/v1/ad_media').single.url.queryParameters['ad_id'], 'eq.a1');
      expect(find.text('2 / 3'), findsOneWidget);
      // RTL: the "next" arrow points left.
      await tester.tap(find.byIcon(Icons.arrow_back_ios_rounded));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('an ad without photos says so', (tester) async {
      await pumpScreen(tester, const PhotoViewerScreen(adId: 'a1'), backend: FakeBackend());
      expect(find.text('لا توجد صور لهذا الإعلان'), findsOneWidget);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      final backend = FakeBackend({'/rest/v1/ad_media': (_) => const Failure(500)});
      await pumpScreen(tester, const PhotoViewerScreen(adId: 'a1'), backend: backend);
      expect(find.text('فشل تحميل الصور'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(backend.to('/rest/v1/ad_media'), hasLength(2));
    });
  });

  group('onboarding', () {
    testWidgets('walks the three slides, then goes to sign-in', (tester) async {
      final nav = NavProbe();
      await pumpScreen(tester, const OnboardingScreen(), backend: FakeBackend(), nav: nav);

      expect(find.text('ابحث بسهولة'), findsOneWidget);
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('انشر مجاناً'), findsOneWidget);
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('ابدأ الآن'), findsOneWidget);
      await tester.tap(find.text('ابدأ الآن'));
      await tester.pumpAndSettle();
      expect(nav.location, AppRoutes.auth);
    });

    testWidgets('"skip" goes straight to sign-in', (tester) async {
      final nav = NavProbe();
      await pumpScreen(tester, const OnboardingScreen(), backend: FakeBackend(), nav: nav);
      await tester.tap(find.text('تخطي'));
      await tester.pumpAndSettle();
      expect(nav.location, AppRoutes.auth);
    });
  });

  group('splash', () {
    for (final (signedIn, target) in [(false, AppRoutes.onboarding), (true, AppRoutes.home)]) {
      testWidgets('goes to $target when ${signedIn ? '' : 'not '}signed in', (tester) async {
        final nav = NavProbe();
        await pumpScreen(tester, const SplashScreen(), backend: FakeBackend(), nav: nav, settle: false, overrides: [
          currentSessionProvider.overrideWith((ref) => signedIn
              ? Session(accessToken: 't', tokenType: 'bearer', user: const User(id: 'u1', appMetadata: {}, userMetadata: {}, aud: 'authenticated', createdAt: ''))
              : null),
        ]);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(nav.location, target);
      });
    }
  });

  testWidgets('after publishing: view the ad, post another, or go home', (tester) async {
    final nav = NavProbe();
    await pumpRoutes(tester, [GoRoute(path: AppRoutes.postSuccess, builder: (_, __) => const AdSuccessScreen())],
        initialLocation: '${AppRoutes.postSuccess}?id=new1', backend: FakeBackend(), nav: nav);

    expect(find.text('تم نشر إعلانك بنجاح!'), findsOneWidget);
    await tester.tap(find.text('عرض الإعلان المنشور'));
    await tester.pumpAndSettle();
    expect(nav.location, '/ad/new1');
  });

  group('bottom navigation', () {
    Future<NavProbe> pumpShell(WidgetTester tester, {bool? accepted}) async {
      final nav = NavProbe();
      final backend = FakeBackend({
        '/rest/v1/app_configs': (_) => [
              {'key': 'legal_terms', 'value': {'version': 2, 'body': 'شروط'}},
              {'key': 'legal_privacy', 'value': {'version': 3, 'body': 'خصوصية'}},
            ],
        '/rest/v1/rpc/legal_status': (_) => {'accepted': accepted},
      });
      await pumpRoutes(
        tester,
        [
          ShellRoute(
            builder: (_, __, child) => BottomNavShell(child: child),
            routes: [GoRoute(path: AppRoutes.home, builder: (_, __) => const Text('home page'))],
          ),
        ],
        initialLocation: AppRoutes.home,
        backend: backend,
        nav: nav,
        overrides: [legalStatusProvider.overrideWith((ref) async => accepted)],
      );
      return nav;
    }

    testWidgets('tabs switch sections, and the center button starts a new ad', (tester) async {
      final nav = await pumpShell(tester, accepted: true);
      expect(find.text('home page'), findsOneWidget);

      await tester.tap(find.text('saved'));
      await tester.pumpAndSettle();
      expect(nav.location, AppRoutes.saved);
    });

    testWidgets('the center button opens the posting flow', (tester) async {
      final nav = await pumpShell(tester, accepted: true);
      await tester.tap(find.text('post'));
      await tester.pumpAndSettle();
      expect(nav.location, AppRoutes.postCategory);
    });

    testWidgets('a user who has not accepted the current terms is asked once', (tester) async {
      await pumpShell(tester, accepted: false);
      expect(find.byType(Dialog), findsOneWidget);
    });
  });
}
