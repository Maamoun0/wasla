import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/core/router/app_router.dart';
import 'package:wasla/features/explore/screens/explore_screen.dart';
import 'package:wasla/features/home/screens/home_screen.dart';
import 'package:wasla/features/notifications/providers/notifications_provider.dart';
import 'package:wasla/data/repositories/ads_repository.dart';
import 'package:wasla/shared/providers/ads_provider.dart';

// Vehicles (1) has the subcategory Cars (11); Real estate (2) is unrelated.
const _categories = [
  {'id': 1, 'name_ar': 'مركبات', 'slug': 'vehicles'},
  {'id': 2, 'name_ar': 'عقارات', 'slug': 'real-estate'},
];
const _parentOf = {1: null, 11: 1, 2: null};

Map<String, dynamic> _ad(String id, String title, int categoryId) => {
      'id': id,
      'title': title,
      'price': 1000,
      'price_type': 'fixed',
      'category_id': categoryId,
      'ad_media': <dynamic>[],
      'cities': {'name_ar': 'القاهرة'},
    };

final _allAds = [
  _ad('a1', 'إعلان مركبات عام', 1),
  _ad('a2', 'إعلان سيارة', 11),
  _ad('a3', 'إعلان شقة', 2),
];

/// Answers like search_ads: a category includes its subcategories. Records the
/// RPC parameters the app would send.
class _FakeSearch extends AdsNotifier {
  _FakeSearch() 
      : super(AdsRepository(SupabaseClient('http://localhost:1', 'k', authOptions: const AuthClientOptions(autoRefreshToken: false))));
  final sentParams = <Map<String, dynamic>>[];

  @override
  Future<void> load({AdsFilter? filter, bool refresh = false}) async {
    final f = filter ?? state.filter;
    final params = searchAdsParams(f, offset: 0);
    sentParams.add(params);
    final cat = params['p_category_id'] as int?;
    final ads = _allAds.where((a) {
      final c = a['category_id'] as int;
      return cat == null || c == cat || _parentOf[c] == cat;
    }).toList();
    state = AdsState(filter: f, ads: ads, hasMore: false);
  }
}

void main() {
  testWidgets('a category on Home opens Explore with that category applied, results from it only, and back returns Home',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final search = _FakeSearch();
    final router = GoRouter(initialLocation: AppRoutes.home, routes: [
      GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: AppRoutes.explore,
        builder: (_, state) => ExploreScreen(initialFilter: adsFilterFromQuery(state.uri.queryParameters)),
      ),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        adsNotifierProvider.overrideWith((ref) => search),
        homeAdsNotifierProvider.overrideWith((ref) => _FakeSearch()),
        categoriesProvider.overrideWith((ref) async => _categories),
        featuredAdsProvider.overrideWith((ref) async => const []),
        unreadCountProvider.overrideWith((ref) async => 0),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('مركبات'));
    await tester.pumpAndSettle();

    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(search.sentParams.last['p_category_id'], 1, reason: 'the category reaches search_ads');
    expect(find.text('إعلان مركبات عام'), findsOneWidget);
    expect(find.text('إعلان سيارة'), findsOneWidget, reason: 'subcategories are included');
    expect(find.text('إعلان شقة'), findsNothing, reason: 'other categories are not');
    expect(GoRouterState.of(tester.element(find.byType(ExploreScreen))).uri.toString(), '/explore?category=1');

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget, reason: 'back returns to Home');
  });

  testWidgets('a deep link opens the search it names, and changing the search updates the URL', (tester) async {
    final search = _FakeSearch();
    final router = GoRouter(initialLocation: '/explore?category=2&q=%D8%B4%D9%82%D8%A9', routes: [
      GoRoute(
        path: AppRoutes.explore,
        builder: (_, state) => ExploreScreen(initialFilter: adsFilterFromQuery(state.uri.queryParameters)),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [adsNotifierProvider.overrideWith((ref) => search)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect([search.sentParams.last['p_category_id'], search.sentParams.last['p_query']], [2, 'شقة']);
    expect(find.text('إعلان شقة'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'دوبلكس');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final uri = GoRouterState.of(tester.element(find.byType(ExploreScreen))).uri;
    expect(uri.queryParameters, {'q': 'دوبلكس', 'category': '2'});
  });

  group('filter <-> URL', () {
    test('round trip keeps every filter', () {
      const f = AdsFilter(query: 'شقة', categoryId: '5', cityId: 2, districtId: 40, adType: 'seeking',
          minPrice: 1000, maxPrice: 2500.5, postedWithinDays: 7, featuredOnly: true);
      expect(sameSearch(adsFilterFromQuery(adsFilterToQuery(f))!, f), isTrue);
      expect(exploreLocation(const AdsFilter()), '/explore');
    });

    test('a plain /explore names no filter; bad values are ignored', () {
      expect(adsFilterFromQuery({}), isNull);
      expect(adsFilterFromQuery({'utm_source': 'x'}), isNull);
      final f = adsFilterFromQuery({'category': 'abc', 'type': 'hack', 'district': '9', 'min': 'cheap', 'q': ' '})!;
      expect([f.categoryId, f.adType, f.districtId, f.minPrice, f.query], [null, null, null, null, null]);
    });
  });
}
