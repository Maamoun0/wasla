import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wasla/features/explore/map/ads_map.dart';
import 'package:wasla/shared/providers/ads_provider.dart';

void main() {
  final cairo = LatLngBounds(southwest: const LatLng(29.8, 31.1), northeast: const LatLng(30.2, 31.6));

  test('the map asks for the visible bounds, zoom and the search\'s filters', () {
    final p = mapClusterParams(MapViewport(bounds: cairo, zoom: 10),
        const AdsFilter(query: ' شقة ', categoryId: '5', adType: 'offering', minPrice: 100, maxPrice: 900, cityId: 3));
    expect(p, {
      'p_min_lat': 29.8, 'p_min_lng': 31.1, 'p_max_lat': 30.2, 'p_max_lng': 31.6, 'p_zoom': 10,
      'p_query': 'شقة', 'p_category_id': 5, 'p_ad_type': 'offering', 'p_min_price': 100.0, 'p_max_price': 900.0,
    });
  });

  test('a cell is either a group or one ad', () {
    final group = MapCluster.fromJson({'lat': 30.06, 'lng': 31.34, 'ad_count': 3, 'ad_id': null, 'title': null, 'price': null});
    final single = MapCluster.fromJson({'lat': 29.96, 'lng': 31.25, 'ad_count': 1, 'ad_id': 'a1', 'title': 'شقة', 'price': 400});
    expect([group.isSingleAd, group.count], [false, 3]);
    expect([single.isSingleAd, single.adId, single.title], [true, 'a1', 'شقة']);
  });

  test('tapping a group zooms in by two levels, within the map\'s range', () {
    expect(zoomInto(10), 12);
    expect(zoomInto(19.5), 20);
    expect(zoomInto(1), 3);
  });

  test('viewports with the same bounds and zoom are the same request', () {
    expect(MapViewport(bounds: cairo, zoom: 10), MapViewport(bounds: cairo, zoom: 10));
    expect(MapViewport(bounds: cairo, zoom: 10) == MapViewport(bounds: cairo, zoom: 11), isFalse);
  });
}
