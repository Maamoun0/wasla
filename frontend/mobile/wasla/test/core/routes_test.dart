import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/core/router/app_router.dart';
import 'package:wasla/features/ads/screens/ad_detail_screen.dart';
import 'package:wasla/features/auth/providers/auth_provider.dart';
import 'package:wasla/features/saved/providers/saved_searches_provider.dart';
import 'package:wasla/features/saved/screens/saved_screen.dart';
import 'package:wasla/shared/providers/ads_provider.dart';

void main() {
  group('isPublicLocation (auth guard)', () {
    test('guests can browse ads, sellers, photos and search', () {
      for (final l in ['/home', '/explore', '/ad/abc', '/seller/u1', '/photos/abc', '/saved', '/profile', '/notifications', '/auth/otp']) {
        expect(isPublicLocation(l), isTrue, reason: l);
      }
    });

    test('posting, payments and account pages need a session', () {
      for (final l in ['/post/category', '/post/form', '/profile/my-ads', '/profile/payment', '/profile/boost/x', '/settings', '/profile/verify', '/ad/abc/edit', '/auth/setup']) {
        expect(isPublicLocation(l), isFalse, reason: l);
      }
    });
  });

  testWidgets('the payment page opened without its data shows "start again" instead of crashing', (tester) async {
    await tester.pumpWidget(MaterialApp(home: paymentScreenFor(null)));
    expect(find.textContaining('انتهت جلسة الدفع'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(home: paymentScreenFor({'paymentUrl': 'https://x', 'transactionId': 7})));
    expect(find.textContaining('انتهت جلسة الدفع'), findsOneWidget);
  });

  testWidgets('"saved alerts" in Profile opens the alerts tab', (tester) async {
    final router = GoRouter(initialLocation: '/saved?tab=alerts', routes: [
      GoRoute(
        path: AppRoutes.saved,
        builder: (_, state) => SavedScreen(initialTab: state.uri.queryParameters['tab'] == 'alerts' ? 1 : 0),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => 'u1'),
        supabaseClientProvider.overrideWith((ref) => SupabaseClient('http://localhost:1', 'k',
            authOptions: const AuthClientOptions(autoRefreshToken: false))),
        favoritesProvider.overrideWith((ref) => Stream.value(const [])),
        savedSearchesProvider.overrideWith((ref) async => [
              {'id': 's1', 'name': 'شقق المعادي', 'keywords': 'شقة', 'is_active': true, 'filters': <String, dynamic>{}},
            ]),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('شقق المعادي'), findsOneWidget);
  });

  testWidgets('tapping an ad photo opens the full-screen viewer at that photo', (tester) async {
    String? opened;
    final router = GoRouter(initialLocation: '/ad/ad1', routes: [
      GoRoute(path: AppRoutes.adDetail, builder: (_, s) => AdDetailScreen(adId: s.pathParameters['id']!)),
      GoRoute(
        path: AppRoutes.photoViewer,
        builder: (_, s) {
          opened = s.uri.toString();
          return const Scaffold(body: Text('viewer'));
        },
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => null),
        adDetailProvider.overrideWith((ref, id) async => {
              'id': id,
              'title': 'شقة',
              'description': 'وصف',
              'price': 1000,
              'price_type': 'fixed',
              'user_id': 'u2',
              'ad_media': [
                {'url': 'https://example.invalid/1.jpg'},
              ],
              'users': {'full_name': 'بائع'},
              'cities': {'name_ar': 'القاهرة'},
            }),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byType(PageView));
    await tester.pump();
    await tester.pump();
    expect(opened, '/photos/ad1?index=0');
  });
}
