import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/data/repositories/ads_repository.dart';
import 'package:wasla/features/explore/screens/explore_screen.dart';
import 'package:wasla/shared/providers/ads_provider.dart';
import 'package:wasla/shared/providers/locations_provider.dart';

/// Records the filters Explore applies instead of calling search_ads.
class _RecordingAdsNotifier extends AdsNotifier {
  _RecordingAdsNotifier(AdsFilter initial)
      : super(AdsRepository(SupabaseClient('http://localhost:1', 'test-key', authOptions: const AuthClientOptions(autoRefreshToken: false)))) {
    state = AdsState(filter: initial, hasMore: false);
  }
  final applied = <AdsFilter>[];

  @override
  Future<void> load({AdsFilter? filter, bool refresh = false}) async {
    if (filter != null) {
      applied.add(filter);
      state = AdsState(filter: filter, hasMore: false);
    }
  }
}

Future<_RecordingAdsNotifier> _pump(WidgetTester tester, AdsFilter initial) async {
  await tester.binding.setSurfaceSize(const Size(800, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final notifier = _RecordingAdsNotifier(initial);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      adsNotifierProvider.overrideWith((ref) => notifier),
      governoratesProvider.overrideWith((ref) async => const [
            {'id': 1, 'name_ar': 'القاهرة'},
          ]),
      citiesProvider.overrideWith((ref, gov) async => const [
            {'id': 11, 'name_ar': 'مدينة نصر', 'governorate_id': 1},
          ]),
      cityByIdProvider.overrideWith((ref, id) async => {'id': id, 'governorate_id': 1, 'name_ar': 'مدينة نصر'}),
      districtsProvider.overrideWith((ref, city) async => const [
            {'id': 101, 'name_ar': 'الحي السابع'},
            {'id': 102, 'name_ar': 'الحي العاشر'},
          ]),
    ],
    child: const MaterialApp(home: ExploreScreen()),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.tune_rounded));
  await tester.pumpAndSettle();
  return notifier;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String label, String option) async {
  await tester.ensureVisible(find.widgetWithText(DropdownButtonFormField<int?>, label));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(DropdownButtonFormField<int?>, label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('district and date are applied together with the query', (tester) async {
    final notifier = await _pump(tester, const AdsFilter(query: 'شقة'));

    await _choose(tester, 'المحافظة', 'القاهرة');
    await _choose(tester, 'المدينة', 'مدينة نصر');
    await _choose(tester, 'الحي', 'الحي العاشر');
    await _tapVisible(tester, find.text('آخر أسبوع'));
    await _tapVisible(tester, find.text('تطبيق'));

    final f = notifier.applied.single;
    expect([f.query, f.cityId, f.districtId, f.postedWithinDays], ['شقة', 11, 102, 7]);
  });

  testWidgets('the sheet opens on the applied filters, and changing the city clears the district', (tester) async {
    final notifier = await _pump(tester, const AdsFilter(cityId: 11, districtId: 101, postedWithinDays: 30));

    expect(find.text('الحي السابع'), findsOneWidget, reason: 'the applied district is shown');
    await _choose(tester, 'المدينة', 'كل المدن');
    await _tapVisible(tester, find.text('تطبيق'));

    final f = notifier.applied.single;
    expect([f.cityId, f.districtId, f.postedWithinDays], [null, null, 30]);
  });
}
