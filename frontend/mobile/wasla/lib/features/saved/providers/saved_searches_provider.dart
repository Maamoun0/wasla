import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/providers/ads_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Server-side cap (validate_saved_search).
const maxSavedSearches = 20;

/// Row for `saved_searches` from the current search, or null when the search
/// has no criterion (the server refuses those: they would alert on every ad).
/// Only what the alert matching supports is saved.
Map<String, dynamic>? savedSearchRow(AdsFilter f,
    {required String userId, String? name}) {
  if (!f.hasCriteria) return null;
  final keywords = f.query?.trim();
  final filters = <String, dynamic>{
    if (f.minPrice != null) 'min_price': f.minPrice,
    if (f.maxPrice != null) 'max_price': f.maxPrice,
    if (f.adType != null) 'ad_type': f.adType,
  };
  final cleanName = name?.trim();
  return {
    'user_id': userId,
    'name': (cleanName == null || cleanName.isEmpty)
        ? defaultSavedSearchName(f)
        : cleanName,
    'category_id': f.categoryId == null ? null : int.tryParse(f.categoryId!),
    'city_id': f.cityId,
    'keywords': (keywords == null || keywords.isEmpty) ? null : keywords,
    'filters': filters,
  };
}

String defaultSavedSearchName(AdsFilter f) {
  final q = f.query?.trim();
  if (q != null && q.isNotEmpty) return q.length > 60 ? q.substring(0, 60) : q;
  return 'بحث محفوظ';
}

/// The search a saved row stands for, to reopen it in Explore.
AdsFilter adsFilterFromSavedSearch(Map<String, dynamic> row) {
  final filters = (row['filters'] as Map?)?.cast<String, dynamic>() ?? const {};
  double? number(Object? v) => v is num ? v.toDouble() : null;
  return AdsFilter(
    query: row['keywords'] as String?,
    categoryId: row['category_id']?.toString(),
    cityId: row['city_id'] as int?,
    adType: filters['ad_type'] as String?,
    minPrice: number(filters['min_price']),
    maxPrice: number(filters['max_price']),
  );
}

class SavedSearchLimitReached implements Exception {
  const SavedSearchLimitReached();
  String get message =>
      'وصلت للحد الأقصى ($maxSavedSearches بحث محفوظ). احذف بحث قديم الأول.';
  @override
  String toString() => message;
}

/// Maps the server's refusal for the 21st search.
Exception savedSearchError(PostgrestException e) =>
    (e.hint == 'saved_search_limit' || e.message.contains('saved search limit'))
        ? const SavedSearchLimitReached()
        : e;

final savedSearchesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('saved_searches')
      .select(
          'id, name, category_id, city_id, keywords, filters, is_active, created_at')
      .eq('user_id', userId)
      .order('created_at', ascending: false);
  return rows.cast<Map<String, dynamic>>();
});

Future<void> saveSearch(SupabaseClient client, Map<String, dynamic> row) async {
  try {
    await client.from('saved_searches').insert(row);
  } on PostgrestException catch (e) {
    throw savedSearchError(e);
  }
}
