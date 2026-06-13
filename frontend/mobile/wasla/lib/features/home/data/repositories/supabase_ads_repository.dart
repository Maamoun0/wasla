import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/ads_repository.dart';

class SupabaseAdsRepository implements AdsRepository {
  final SupabaseClient _client;

  SupabaseAdsRepository(this._client);

  @override
  Future<List<Map<String, dynamic>>> getFeaturedAds({int limit = 10}) async {
    final response = await _client
        .from('ads')
        .select('*, users(full_name, avatar_url, trust_score), cities(name_ar), ad_media(*)')
        .eq('is_featured', true)
        .eq('status', 'active')
        .order('published_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> getNearbyAds({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    int limit = 20,
  }) async {
    // استدعاء Edge Function الخاص بالإعلانات القريبة
    final response = await _client.functions.invoke(
      'ads-nearby',
      method: HttpMethod.get,
      queryParameters: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius': radiusKm.toString(),
        'limit': limit.toString(),
      },
    );
    
    if (response.status == 200 && response.data is List) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getCategories({int? parentId}) async {
    var query = _client
        .from('categories')
        .select('*')
        .eq('is_active', true);

    if (parentId != null) {
      query = query.eq('parent_id', parentId);
    } else {
      query = query.isFilter('parent_id', null);
    }

    final response = await query.order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> searchAds({
    required String query,
    Map<String, dynamic>? filters,
    int limit = 20,
    int offset = 0,
  }) async {
    // استدعاء Edge Function الخاص بالبحث المتقدم لدعم البحث الذكي بالنصوص والفلاتر المعقدة
    final response = await _client.functions.invoke(
      'search-ads',
      method: HttpMethod.get,
      queryParameters: {
        'q': query,
        if (filters != null) 'filters': filters.toString(),
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    if (response.status == 200 && response.data is List) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> getAdDetails(String adId) async {
    final response = await _client
        .from('ads')
        .select('*, users(*), cities(*), districts(*), ad_media(*), ad_fields(*, category_fields(*))')
        .eq('id', adId)
        .single();
    return Map<String, dynamic>.from(response);
  }

  @override
  Future<void> addToFavorites(String adId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('يجب تسجيل الدخول للإضافة للمفضلة');

    await _client.from('favorites').insert({
      'user_id': userId,
      'ad_id': adId,
    });
  }

  @override
  Future<void> removeFromFavorites(String adId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('يجب تسجيل الدخول لإزالة المفضلة');

    await _client.from('favorites').delete().match({
      'user_id': userId,
      'ad_id': adId,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getFavoriteAds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('favorites')
        .select('*, ads(*, users(full_name, avatar_url, trust_score), cities(name_ar), ad_media(*))')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<void> logContact(String adId, String contactType) async {
    final userId = _client.auth.currentUser?.id;
    await _client.from('contact_logs').insert({
      'ad_id': adId,
      if (userId != null) 'user_id': userId,
      'contact_type': contactType,
    });
  }

  @override
  Future<String> createAd(Map<String, dynamic> adData) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('يجب تسجيل الدخول لنشر إعلان');

    final adPayload = {
      ...adData,
      'user_id': userId,
      'status': 'pending', // يبدأ الإعلان دائماً معلقاً للمراجعة
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await _client.from('ads').insert(adPayload).select('id').single();
    return response['id'] as String;
  }

  @override
  Future<void> updateAdStatus(String adId, String status) async {
    await _client.from('ads').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', adId);
  }
}
