import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/features/auth/providers/auth_provider.dart';
import 'package:wasla/features/saved/providers/saved_ads_provider.dart';
import 'package:wasla/features/saved/screens/saved_screen.dart';
import 'package:wasla/shared/providers/ads_provider.dart';

final _fav = {
  'id': 'f1',
  'notes': null,
  'ads': {'id': 'a1', 'title': 'آيفون محفوظ', 'price': 1000, 'ad_media': <dynamic>[], 'cities': {'name_ar': 'القاهرة'}},
};

Future<void> _pump(WidgetTester tester, Future<List<Map<String, dynamic>>> Function(String) fetch) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      supabaseClientProvider.overrideWith((ref) => SupabaseClient('http://localhost:1', 'k',
          authOptions: const AuthClientOptions(autoRefreshToken: false))),
      favoritesProvider.overrideWith((ref) => Stream.value(const [])),
      savedAdsFetcherProvider.overrideWith((ref) => fetch),
    ],
    child: const MaterialApp(home: SavedScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('online: the list is shown and kept on the device', (tester) async {
    await _pump(tester, (_) async => [_fav]);
    expect(find.text('آيفون محفوظ'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    expect((await SavedAdsCache.read('u1'))!.items.single['id'], 'f1');
  });

  testWidgets('offline: the last copy is shown with a notice (NFR-3.2)', (tester) async {
    await SavedAdsCache.write('u1', [_fav], at: DateTime(2026, 11, 1, 9, 5));
    await _pump(tester, (_) async => throw Exception('SocketException'));
    expect(find.text('آيفون محفوظ'), findsOneWidget);
    expect(find.textContaining('آخر نسخة محفوظة'), findsOneWidget);
  });

  testWidgets('offline with no copy: a clear error, not "no saved ads"', (tester) async {
    await _pump(tester, (_) async => throw Exception('SocketException'));
    expect(find.text('تعذّر تحميل المحفوظات'), findsOneWidget);
  });

  test('sign-out clears every copy; copies are per user', () async {
    await SavedAdsCache.write('u1', [_fav]);
    await SavedAdsCache.write('u2', [_fav]);
    expect(await SavedAdsCache.read('u3'), isNull);
    await SavedAdsCache.clearAll();
    expect([await SavedAdsCache.read('u1'), await SavedAdsCache.read('u2')], [null, null]);
  });
}
