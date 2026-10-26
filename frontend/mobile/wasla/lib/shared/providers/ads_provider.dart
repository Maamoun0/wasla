import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/providers/auth_provider.dart';

// ── Ad Detail Provider ────────────────────────────────────────────
final adDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
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
  return response;
});

// ── Ads List State ────────────────────────────────────────────────
class AdsFilter {
  final String? categoryId;
  final int? cityId;
  final String? adType;
  final double? minPrice;
  final double? maxPrice;
  final bool featuredOnly;
  final String? query;
  final int page;
  final int limit;

  const AdsFilter({
    this.categoryId,
    this.cityId,
    this.adType,
    this.minPrice,
    this.maxPrice,
    this.featuredOnly = false,
    this.query,
    this.page = 1,
    this.limit = 20,
  });

  AdsFilter copyWith({
    String? categoryId,
    int? cityId,
    String? adType,
    double? minPrice,
    double? maxPrice,
    bool? featuredOnly,
    String? query,
    int? page,
    int? limit,
  }) {
    return AdsFilter(
      categoryId:   categoryId   ?? this.categoryId,
      cityId:       cityId       ?? this.cityId,
      adType:       adType       ?? this.adType,
      minPrice:     minPrice     ?? this.minPrice,
      maxPrice:     maxPrice     ?? this.maxPrice,
      featuredOnly: featuredOnly ?? this.featuredOnly,
      query:        query        ?? this.query,
      page:         page         ?? this.page,
      limit:        limit        ?? this.limit,
    );
  }
}

class AdsState {
  final List<Map<String, dynamic>> ads;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final AdsFilter filter;

  const AdsState({
    this.ads = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.filter = const AdsFilter(),
  });

  AdsState copyWith({
    List<Map<String, dynamic>>? ads,
    bool? isLoading,
    bool? hasMore,
    String? error,
    AdsFilter? filter,
  }) {
    return AdsState(
      ads:       ads       ?? this.ads,
      isLoading: isLoading ?? this.isLoading,
      hasMore:   hasMore   ?? this.hasMore,
      error:     error,
      filter:    filter    ?? this.filter,
    );
  }
}

/// Parameters for the search_ads RPC.
Map<String, dynamic> searchAdsParams(AdsFilter f, {required int offset}) {
  final query = f.query?.trim();
  return {
    if (query != null && query.isNotEmpty) 'p_query': query,
    if (f.categoryId != null) 'p_category_id': int.tryParse(f.categoryId!),
    if (f.cityId != null) 'p_city_id': f.cityId,
    if (f.adType != null) 'p_ad_type': f.adType,
    if (f.minPrice != null) 'p_min_price': f.minPrice,
    if (f.maxPrice != null) 'p_max_price': f.maxPrice,
    'p_featured_only': f.featuredOnly,
    'p_limit': f.limit,
    'p_offset': offset,
  };
}

class AdsNotifier extends StateNotifier<AdsState> {
  final SupabaseClient _client;

  AdsNotifier(this._client) : super(const AdsState());

  static const String _adSelect = '''
    id, title, price, price_type, city_id, is_featured, is_urgent,
    views_count, published_at, status, ad_type, created_at,
    ad_media(url, is_primary, sort_order),
    cities(name_ar)
  ''';

  Future<void> load({AdsFilter? filter, bool refresh = false}) async {
    final f = filter ?? state.filter;

    if (state.isLoading) return;
    if (!state.hasMore && !refresh) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      filter: f,
      ads: refresh ? [] : state.ads,
    );

    try {
      // search_ads applies the text query (Arabic-normalised, prefix and
      // typo tolerant) and every filter, and orders featured ads first.
      final offset = refresh ? 0 : state.ads.length;
      final List<dynamic> results = await _client
          .rpc('search_ads', params: searchAdsParams(f, offset: offset))
          .select(_adSelect);
      final newAds = results.cast<Map<String, dynamic>>();

      state = state.copyWith(
        ads:       refresh ? newAds : [...state.ads, ...newAds],
        hasMore:   newAds.length == f.limit,
        isLoading: false,
        filter:    f,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load(refresh: true);

  void applyFilter(AdsFilter filter) => load(filter: filter, refresh: true);

  void clearFilters() => load(filter: const AdsFilter(), refresh: true);
}

final adsNotifierProvider = StateNotifierProvider<AdsNotifier, AdsState>((ref) {
  return AdsNotifier(ref.watch(supabaseClientProvider));
});

// ── Featured Ads ──────────────────────────────────────────────────
final featuredAdsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client
      .from('ads')
      .select('id,title,price,price_type,city_id,ad_media(url,is_primary),cities(name_ar)')
      .eq('status', 'active')
      .eq('is_featured', true)
      .order('published_at', ascending: false)
      .limit(10);
  return (res as List).cast<Map<String, dynamic>>();
});

// ── Categories Provider ────────────────────────────────────────────
final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client
      .from('categories')
      .select()
      .eq('is_active', true)
      .eq('level', 1)
      .order('sort_order');
  return (res as List).cast<Map<String, dynamic>>();
});

final subCategoriesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, parentId) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client
      .from('categories')
      .select()
      .eq('parent_id', parentId)
      .eq('is_active', true)
      .order('sort_order');
  return (res as List).cast<Map<String, dynamic>>();
});

// ── Favorites Provider ─────────────────────────────────────────────
final favoritesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  return client
      .from('favorites')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((data) => data.cast<Map<String, dynamic>>());
});

// Toggle favorite
Future<void> toggleFavorite({
  required SupabaseClient client,
  required String adId,
  required String userId,
  required bool isFavorited,
}) async {
  if (isFavorited) {
    await client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('ad_id', adId);
  } else {
    await client.from('favorites').insert({
      'user_id': userId,
      'ad_id': adId,
    });
  }
}

// ── Seller Contact ─────────────────────────────────────────────────
// The seller's phone is not readable from `users`. reveal_seller_phone
// returns it to signed-in users for active ads, rate-limited per user,
// and records the contact.
sealed class SellerPhoneResult {
  const SellerPhoneResult();
}

class SellerPhoneRevealed extends SellerPhoneResult {
  const SellerPhoneRevealed(this.phone);
  final String phone;
}

class SellerPhoneRateLimited extends SellerPhoneResult {
  const SellerPhoneRateLimited(this.retryAfter);
  final Duration retryAfter;
}

class SellerPhoneUnavailable extends SellerPhoneResult {
  const SellerPhoneUnavailable();
}

SellerPhoneResult parseSellerPhoneResponse(Object? res) {
  final map = res is Map ? res : const {};
  switch (map['status']) {
    case 'ok':
      final phone = map['phone'] as String? ?? '';
      return phone.isEmpty ? const SellerPhoneUnavailable() : SellerPhoneRevealed(phone);
    case 'rate_limited':
      return SellerPhoneRateLimited(Duration(seconds: (map['retry_after_seconds'] as num?)?.toInt() ?? 60));
    default:
      return const SellerPhoneUnavailable();
  }
}

Future<SellerPhoneResult> revealSellerPhone({
  required SupabaseClient client,
  required String adId,
  required String contactType,
}) async {
  final res = await client.rpc('reveal_seller_phone', params: {
    'p_ad_id': adId,
    'p_contact_type': contactType,
  });
  return parseSellerPhoneResponse(res);
}

// ── Notifications Provider ─────────────────────────────────────────
final notificationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  return client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .map((data) => data.cast<Map<String, dynamic>>());
});

final unreadCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider);
  return notifs.maybeWhen(
    data: (list) => list.where((n) => n['is_read'] == false).length,
    orElse: () => 0,
  );
});
