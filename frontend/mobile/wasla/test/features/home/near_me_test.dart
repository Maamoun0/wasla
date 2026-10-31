import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/core/location/location_service.dart';
import 'package:wasla/features/home/screens/home_screen.dart';
import 'package:wasla/features/notifications/providers/notifications_provider.dart';
import 'package:wasla/shared/providers/ads_provider.dart';

class _RecordingFeed extends AdsNotifier {
  _RecordingFeed() : super(SupabaseClient('http://localhost:1', 'k', authOptions: const AuthClientOptions(autoRefreshToken: false)));
  final params = <Map<String, dynamic>>[];

  @override
  Future<void> load({AdsFilter? filter, bool refresh = false}) async {
    final f = filter ?? state.filter;
    params.add(searchAdsParams(f, offset: 0));
    state = AdsState(filter: f, hasMore: false);
  }
}

Future<_RecordingFeed> _pump(WidgetTester tester, LocationResult location) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final feed = _RecordingFeed();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      homeAdsNotifierProvider.overrideWith((ref) => feed),
      categoriesProvider.overrideWith((ref) async => const []),
      featuredAdsProvider.overrideWith((ref) async => const []),
      unreadCountProvider.overrideWith((ref) async => 0),
      locationReaderProvider.overrideWith((ref) => () async => location),
    ],
    child: const MaterialApp(home: HomeScreen()),
  ));
  await tester.pumpAndSettle();
  return feed;
}

void main() {
  testWidgets('"near me" sends the rounded position and a 50 km radius to search_ads', (tester) async {
    final feed = await _pump(tester, LocationResult.found(ApproxLocation.round(30.04437, 31.23571)));
    await tester.tap(find.text('الأقرب لي'));
    await tester.pumpAndSettle();

    final p = feed.params.last;
    expect([p['p_near_lat'], p['p_near_lng'], p['p_radius_km']], [30.04, 31.24, 50.0]);
    expect(find.text('الأقرب ليك'), findsOneWidget);

    await tester.tap(find.text('الأحدث'));
    await tester.pumpAndSettle();
    expect(feed.params.last.containsKey('p_near_lat'), isFalse, reason: 'back to the latest ads');
  });

  testWidgets('without location permission the user is told why and the feed is unchanged', (tester) async {
    final feed = await _pump(tester, const LocationResult.failed(LocationIssue.denied));
    final before = feed.params.length;
    await tester.tap(find.text('الأقرب لي'));
    await tester.pumpAndSettle();
    expect(find.textContaining('إذن الموقع'), findsOneWidget);
    expect(feed.params.length, before);
  });

  test('the position is rounded to ~1 km and never goes into links', () {
    final here = ApproxLocation.round(30.044379, 31.235712);
    expect([here.lat, here.lng], [30.04, 31.24]);
    final f = AdsFilter(nearLat: here.lat, nearLng: here.lng, radiusKm: 50, query: 'شقة');
    expect(adsFilterToQuery(f), {'q': 'شقة'});
  });
}
