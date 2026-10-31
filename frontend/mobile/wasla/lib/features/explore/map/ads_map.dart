import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../shared/providers/ads_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// One map cell from ads_map_clusters: a group of ads, or a single ad.
class MapCluster {
  const MapCluster({required this.lat, required this.lng, required this.count, this.adId, this.title, this.price});

  final double lat;
  final double lng;
  final int count;
  final String? adId;
  final String? title;
  final num? price;

  bool get isSingleAd => count == 1 && adId != null;

  factory MapCluster.fromJson(Map<String, dynamic> j) => MapCluster(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        count: (j['ad_count'] as num).toInt(),
        adId: j['ad_id'] as String?,
        title: j['title'] as String?,
        price: j['price'] as num?,
      );
}

/// What the map currently shows.
class MapViewport {
  const MapViewport({required this.bounds, required this.zoom});
  final LatLngBounds bounds;
  final int zoom;

  @override
  bool operator ==(Object other) => other is MapViewport && other.bounds == bounds && other.zoom == zoom;
  @override
  int get hashCode => Object.hash(bounds, zoom);
}

/// ads_map_clusters parameters: the viewport plus the search's filters.
Map<String, dynamic> mapClusterParams(MapViewport v, AdsFilter f) {
  final q = f.query?.trim();
  return {
    'p_min_lat': v.bounds.southwest.latitude,
    'p_min_lng': v.bounds.southwest.longitude,
    'p_max_lat': v.bounds.northeast.latitude,
    'p_max_lng': v.bounds.northeast.longitude,
    'p_zoom': v.zoom,
    if (q != null && q.isNotEmpty) 'p_query': q,
    if (f.categoryId != null) 'p_category_id': int.tryParse(f.categoryId!),
    if (f.adType != null) 'p_ad_type': f.adType,
    if (f.minPrice != null) 'p_min_price': f.minPrice,
    if (f.maxPrice != null) 'p_max_price': f.maxPrice,
  };
}

/// Tapping a group zooms in enough to start splitting it.
double zoomInto(double currentZoom) => (currentZoom + 2).clamp(3, 20).toDouble();

/// Egypt, the first view.
const egyptCenter = LatLng(26.8, 30.8);

final mapClustersProvider = FutureProvider.autoDispose.family<List<MapCluster>, MapViewport>((ref, viewport) async {
  final filter = ref.watch(adsNotifierProvider.select((s) => s.filter));
  final rows = await ref.watch(supabaseClientProvider).rpc('ads_map_clusters', params: mapClusterParams(viewport, filter));
  return (rows as List).cast<Map<String, dynamic>>().map(MapCluster.fromJson).toList();
});

/// Explore's map view (FR-2.4). Needs a Google Maps key in the build
/// (MAPS_API_KEY); without one the map shows Google's error tiles.
class AdsMapView extends ConsumerStatefulWidget {
  const AdsMapView({super.key});

  @override
  ConsumerState<AdsMapView> createState() => _AdsMapViewState();
}

class _AdsMapViewState extends ConsumerState<AdsMapView> {
  GoogleMapController? _controller;
  MapViewport? _viewport;
  double _zoom = 5;

  Future<void> _refreshViewport() async {
    final c = _controller;
    if (c == null) return;
    final bounds = await c.getVisibleRegion();
    if (!mounted) return;
    setState(() => _viewport = MapViewport(bounds: bounds, zoom: _zoom.round()));
  }

  Set<Marker> _markers(List<MapCluster> clusters) => {
        for (final cl in clusters)
          Marker(
            markerId: MarkerId('${cl.lat},${cl.lng}'),
            position: LatLng(cl.lat, cl.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(cl.isSingleAd ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure),
            infoWindow: cl.isSingleAd
                ? InfoWindow(
                    title: cl.title,
                    snippet: cl.price == null ? null : '${cl.price} ج.م',
                    onTap: () => context.push('/ad/${cl.adId}'),
                  )
                : InfoWindow(title: '${cl.count} إعلان', snippet: 'اضغط للتقريب'),
            onTap: cl.isSingleAd
                ? null
                : () => _controller?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(cl.lat, cl.lng), zoomInto(_zoom))),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final viewport = _viewport;
    final clusters = viewport == null ? null : ref.watch(mapClustersProvider(viewport));
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: egyptCenter, zoom: _zoom),
          myLocationButtonEnabled: false,
          markers: _markers(clusters?.valueOrNull ?? const []),
          onMapCreated: (c) {
            _controller = c;
            _refreshViewport();
          },
          onCameraMove: (p) => _zoom = p.zoom,
          onCameraIdle: _refreshViewport,
        ),
        if (clusters?.isLoading ?? false)
          const Positioned(top: 12, left: 0, right: 0, child: Center(child: CircularProgressIndicator())),
        if (clusters?.hasError ?? false)
          const Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Material(
              elevation: 2,
              child: Padding(padding: EdgeInsets.all(8), child: Text('تعذّر تحميل الإعلانات على الخريطة')),
            ),
          ),
      ],
    );
  }
}
