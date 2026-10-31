import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/features/ads/screens/ad_detail_screen.dart';
import 'package:wasla/features/auth/providers/auth_provider.dart';
import 'package:wasla/features/profile/providers/ad_performance_provider.dart';
import 'package:wasla/features/profile/screens/ad_performance_screen.dart';
import 'package:wasla/shared/providers/ads_provider.dart';

Map<String, dynamic> _json() => {
      'title': 'آيفون 13',
      'views': 200,
      'favorites': 7,
      'calls': 3,
      'whatsapp': 5,
      'expires_at': '2026-11-30T12:00:00Z',
      'daily': [
        for (var i = 0; i < 30; i++) {'day': '2026-10-${(i + 2).toString().padLeft(2, '0')}', 'views': i, 'contacts': i % 3},
      ],
    };

void main() {
  test('reads ad_performance as the server returns it', () {
    final p = AdPerformance.fromJson(_json());
    expect([p.views, p.calls, p.whatsapp, p.contacts, p.favorites, p.daily.length], [200, 3, 5, 8, 7, 30]);
    expect(p.contactRate, 4.0);
    expect(AdPerformance.fromJson({'views': 0}).contactRate, isNull);
  });

  testWidgets('the screen shows the totals and the contact rate', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [adPerformanceProvider.overrideWith((ref, id) async => AdPerformance.fromJson(_json()))],
      child: const MaterialApp(home: AdPerformanceScreen(adId: 'ad-1')),
    ));
    await tester.pumpAndSettle();
    for (final v in ['200', '3', '5', '7']) {
      expect(find.text(v), findsWidgets, reason: v);
    }
    expect(find.textContaining('4.0'), findsOneWidget);
    expect(find.text('آخر 30 يوم'), findsOneWidget);
  });

  testWidgets('opening an ad records one view', (tester) async {
    final recorded = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => null),
        supabaseClientProvider.overrideWith((ref) => SupabaseClient('http://localhost:1', 'k',
            authOptions: const AuthClientOptions(autoRefreshToken: false))),
        adViewRecorderProvider.overrideWith((ref) => (id) async => recorded.add(id)),
        adDetailProvider.overrideWith((ref, id) async => {
              'id': id, 'title': 'x', 'description': 'd', 'price': 1, 'price_type': 'fixed', 'user_id': 's',
              'ad_media': <dynamic>[], 'users': <String, dynamic>{}, 'cities': <String, dynamic>{},
            }),
      ],
      child: const MaterialApp(home: AdDetailScreen(adId: 'ad-9')),
    ));
    await tester.pumpAndSettle();
    expect(recorded, ['ad-9']);
  });
}
