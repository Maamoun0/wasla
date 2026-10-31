import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/features/saved/providers/saved_searches_provider.dart';
import 'package:wasla/shared/providers/ads_provider.dart';

void main() {
  group('savedSearchRow', () {
    test('a search with no criterion cannot be saved', () {
      expect(savedSearchRow(const AdsFilter(), userId: 'u1'), isNull);
      expect(savedSearchRow(const AdsFilter(query: '   '), userId: 'u1'), isNull);
    });

    test('maps the current search to the columns the alert matching reads', () {
      const f = AdsFilter(
        query: ' تويوتا كورولا ',
        categoryId: '12',
        cityId: 3,
        adType: 'offering',
        minPrice: 100000,
        maxPrice: 400000,
        featuredOnly: true,
      );
      expect(savedSearchRow(f, userId: 'u1', name: '  عربيتي  '), {
        'user_id': 'u1',
        'name': 'عربيتي',
        'category_id': 12,
        'city_id': 3,
        'keywords': 'تويوتا كورولا',
        'filters': {'min_price': 100000.0, 'max_price': 400000.0, 'ad_type': 'offering'},
      });
    });

    test('the name defaults to the query, or a generic name', () {
      expect(savedSearchRow(const AdsFilter(query: 'شقة'), userId: 'u1')!['name'], 'شقة');
      expect(savedSearchRow(const AdsFilter(cityId: 1), userId: 'u1', name: ' ')!['name'], 'بحث محفوظ');
    });
  });

  test('a saved row reopens the same search', () {
    const original = AdsFilter(query: 'شقة', categoryId: '5', cityId: 2, districtId: 40, adType: 'seeking', minPrice: 1000, maxPrice: 5000);
    final row = savedSearchRow(original, userId: 'u1')!;
    expect(row['filters'], {'min_price': 1000.0, 'max_price': 5000.0, 'ad_type': 'seeking', 'district_id': 40});
    // As returned by PostgREST: ints for whole-number prices.
    row['filters'] = {'min_price': 1000, 'max_price': 5000, 'ad_type': 'seeking', 'district_id': 40};
    final reopened = adsFilterFromSavedSearch(row);
    expect(searchAdsParams(reopened, offset: 0), searchAdsParams(original, offset: 0));
  });

  test('district and date reach search_ads; the date is not saved in an alert', () {
    const f = AdsFilter(cityId: 2, districtId: 40, postedWithinDays: 7);
    final params = searchAdsParams(f, offset: 0);
    expect([params['p_city_id'], params['p_district_id'], params['p_posted_within_days']], [2, 40, 7]);
    expect(savedSearchRow(const AdsFilter(postedWithinDays: 7), userId: 'u1'), isNull, reason: 'a date alone is not an alert');
    expect((savedSearchRow(f, userId: 'u1')!['filters'] as Map).containsKey('posted_within_days'), isFalse);
  });

  group('AdsFilter keeps the rest of the search', () {
    const f = AdsFilter(query: 'لابتوب', categoryId: '7', cityId: 1, adType: 'offering', minPrice: 10, maxPrice: 20);

    test('a new query keeps place and refinements; null clears only the text', () {
      final g = f.withQuery(null);
      expect([g.query, g.categoryId, g.cityId, g.adType, g.minPrice, g.maxPrice], [null, '7', 1, 'offering', 10, 20]);
    });

    test('the filter sheet replaces its own values and keeps the query and category', () {
      final g = f.withRefinements(cityId: 2, districtId: 9, minPrice: 50, postedWithinDays: 7);
      expect([g.query, g.categoryId, g.cityId, g.districtId, g.adType, g.minPrice, g.maxPrice, g.postedWithinDays],
          ['لابتوب', '7', 2, 9, null, 50, null, 7]);
    });

    test('a district without a city is dropped', () {
      expect(f.withRefinements(districtId: 9).districtId, isNull);
    });
  });

  test('the server refusal for the 21st search becomes a clear message', () {
    final e = savedSearchError(const PostgrestException(message: 'saved search limit reached', code: 'P0001', hint: 'saved_search_limit'));
    expect(e, isA<SavedSearchLimitReached>());
    expect((e as SavedSearchLimitReached).message, contains('20'));
    expect(savedSearchError(const PostgrestException(message: 'other', code: '22023')), isA<PostgrestException>());
  });
}
