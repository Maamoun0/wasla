import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/shared/providers/ads_provider.dart';

void main() {
  group('searchAdsParams', () {
    test('sends the search text and every filter', () {
      const f = AdsFilter(
        query: '  تويوتا كورولا ',
        categoryId: '4',
        cityId: 2,
        adType: 'seeking',
        minPrice: 1000,
        maxPrice: 50000,
        featuredOnly: true,
        limit: 20,
      );
      expect(searchAdsParams(f, offset: 40), {
        'p_query': 'تويوتا كورولا',
        'p_category_id': 4,
        'p_city_id': 2,
        'p_ad_type': 'seeking',
        'p_min_price': 1000.0,
        'p_max_price': 50000.0,
        'p_featured_only': true,
        'p_limit': 20,
        'p_offset': 40,
      });
    });

    test('omits empty text and unset filters', () {
      expect(searchAdsParams(const AdsFilter(query: '   '), offset: 0), {
        'p_featured_only': false,
        'p_limit': 20,
        'p_offset': 0,
      });
    });
  });
}
