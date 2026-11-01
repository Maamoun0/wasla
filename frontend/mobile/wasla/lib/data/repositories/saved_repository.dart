import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client_provider.dart';

/// The user's favorites and saved searches.
class SavedRepository {
  SavedRepository(this._client);

  final SupabaseClient _client;

  /// Favorites with their ads, newest first.
  Future<List<Map<String, dynamic>>> favoritesWithAds(String userId) async => (await _client.from('favorites').select('''
        id, notes, created_at,
        ads(id, title, price, price_type, status, city_id,
          ad_media(url, is_primary),
          cities(name_ar))
      ''').eq('user_id', userId).order('created_at', ascending: false)).cast<Map<String, dynamic>>();

  Future<void> removeFavorite(Object favoriteId) => _client.from('favorites').delete().eq('id', favoriteId);

  Future<List<Map<String, dynamic>>> savedSearches(String userId) async => (await _client
          .from('saved_searches')
          .select('id, name, category_id, city_id, keywords, filters, is_active, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false))
      .cast<Map<String, dynamic>>();

  /// Throws PostgrestException as the database raised it.
  Future<void> insertSavedSearch(Map<String, dynamic> row) => _client.from('saved_searches').insert(row);

  Future<void> setSavedSearchActive(Object id, bool active) =>
      _client.from('saved_searches').update({'is_active': active}).eq('id', id);

  Future<void> deleteSavedSearch(Object id) => _client.from('saved_searches').delete().eq('id', id);
}

final savedRepositoryProvider = Provider<SavedRepository>((ref) => SavedRepository(ref.watch(supabaseClientProvider)));
