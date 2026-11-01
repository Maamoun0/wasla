import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client_provider.dart';

/// Ads, categories, favorites and seller contact (Rule 4.1: providers go
/// through repositories, never through the Supabase client directly).
class AdsRepository {
  AdsRepository(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<Map<String, dynamic>> getAd(String id) => _client
      .from('ads')
      .select('''
        *,
        ad_media(*),
        ad_fields(*, category_fields(label_ar, label_en, field_type)),
        users(full_name, avatar_url, trust_score, is_id_verified),
        cities(name_ar),
        districts(name_ar),
        categories(name_ar, name_en)
      ''')
      .eq('id', id)
      .single();

  /// search_ads applies the text query (Arabic-normalised, prefix and typo
  /// tolerant) and every filter, and orders featured ads first.
  Future<List<Map<String, dynamic>>> searchAds(Map<String, dynamic> params, String select) async {
    final List<dynamic> results = await _client.rpc('search_ads', params: params).select(select);
    return results.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> featuredAds() async {
    final res = await _client
        .from('ads')
        .select('id,title,price,price_type,city_id,ad_media(url,is_primary),cities(name_ar)')
        .eq('status', 'active')
        .eq('is_featured', true)
        .order('published_at', ascending: false)
        .limit(10);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> topCategories() async {
    final res = await _client.from('categories').select().eq('is_active', true).eq('level', 1).order('sort_order');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> subCategories(int parentId) async {
    final res =
        await _client.from('categories').select().eq('parent_id', parentId).eq('is_active', true).order('sort_order');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Stream<List<Map<String, dynamic>>> watchFavorites(String userId) => _client
      .from('favorites')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((data) => data.cast<Map<String, dynamic>>());

  Future<bool> isFavorite({required String userId, required String adId}) async =>
      await _client.from('favorites').select('id').eq('user_id', userId).eq('ad_id', adId).maybeSingle() != null;

  Future<void> reportAd({required String reporterId, required String adId, required String reason}) => _client
      .from('reports')
      .insert({'reporter_id': reporterId, 'target_type': 'ad', 'target_id': adId, 'reason': reason});

  Future<void> setFavorite({required String userId, required String adId, required bool favorite}) async {
    if (favorite) {
      await _client.from('favorites').insert({'user_id': userId, 'ad_id': adId});
    } else {
      await _client.from('favorites').delete().eq('user_id', userId).eq('ad_id', adId);
    }
  }

  /// The photos of one ad, in order.
  Future<List<String>> photoUrls(String adId) async {
    final rows = await _client.from('ad_media').select('url').eq('ad_id', adId).order('sort_order', ascending: true);
    return rows.map<String>((media) => media['url'] as String).toList();
  }

  /// The user's own ads in one status, newest first.
  Future<List<Map<String, dynamic>>> myAds(String userId, String status) async => (await _client.from('ads').select('''
        id, title, price, price_type, views_count, contacts_count, favorites_count,
        created_at, expires_at, rejection_reason, is_featured,
        ad_media(url, is_primary),
        cities(name_ar)
      ''').eq('user_id', userId).eq('status', status).order('created_at', ascending: false))
      .cast<Map<String, dynamic>>();

  Future<Object?> renewAd(String adId) => _client.rpc('renew_ad', params: {'p_ad_id': adId});

  Future<Map<String, dynamic>> adPerformance(String adId) async =>
      ((await _client.rpc('ad_performance', params: {'p_ad_id': adId})) as Map).cast<String, dynamic>();

  /// record_ad_view decides what counts as a view.
  Future<void> recordAdView(String adId) =>
      _client.rpc('record_ad_view', params: {'p_ad_id': adId, 'p_source': 'app'});

  Future<List<Map<String, dynamic>>> mapClusters(Map<String, dynamic> params) async =>
      ((await _client.rpc('ads_map_clusters', params: params)) as List).cast<Map<String, dynamic>>();

  /// The seller's phone is not readable from `users`. reveal_seller_phone
  /// returns it to signed-in users for active ads, rate-limited per user, and
  /// records the contact.
  Future<Object?> revealSellerPhone({required String adId, required String contactType}) =>
      _client.rpc('reveal_seller_phone', params: {'p_ad_id': adId, 'p_contact_type': contactType});
}

final adsRepositoryProvider = Provider<AdsRepository>((ref) => AdsRepository(ref.watch(supabaseClientProvider)));
