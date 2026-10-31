import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final int? districtId;
  final String? adType;
  final double? minPrice;
  final double? maxPrice;
  /// Only ads published in the last N days.
  final int? postedWithinDays;
  /// "Near me": closest first from this (rounded) point, within [radiusKm].
  /// Never written to the URL or saved.
  final double? nearLat;
  final double? nearLng;
  final double? radiusKm;
  final bool featuredOnly;
  final String? query;
  final int page;
  final int limit;

  const AdsFilter({
    this.categoryId,
    this.cityId,
    this.districtId,
    this.adType,
    this.minPrice,
    this.maxPrice,
    this.postedWithinDays,
    this.nearLat,
    this.nearLng,
    this.radiusKm,
    this.featuredOnly = false,
    this.query,
    this.page = 1,
    this.limit = 20,
  });

  bool get isNearMe => nearLat != null && nearLng != null;

  AdsFilter copyWith({
    String? categoryId,
    int? cityId,
    int? districtId,
    String? adType,
    double? minPrice,
    double? maxPrice,
    int? postedWithinDays,
    bool? featuredOnly,
    String? query,
    int? page,
    int? limit,
  }) {
    return AdsFilter(
      categoryId:   categoryId   ?? this.categoryId,
      cityId:       cityId       ?? this.cityId,
      districtId:   districtId   ?? this.districtId,
      adType:       adType       ?? this.adType,
      minPrice:     minPrice     ?? this.minPrice,
      maxPrice:     maxPrice     ?? this.maxPrice,
      postedWithinDays: postedWithinDays ?? this.postedWithinDays,
      featuredOnly: featuredOnly ?? this.featuredOnly,
      query:        query        ?? this.query,
      page:         page         ?? this.page,
      limit:        limit        ?? this.limit,
    );
  }

  /// Same filters with another text query (null clears it). copyWith cannot clear.
  AdsFilter withQuery(String? newQuery) => AdsFilter(
        categoryId: categoryId,
        cityId: cityId,
        districtId: districtId,
        adType: adType,
        minPrice: minPrice,
        maxPrice: maxPrice,
        postedWithinDays: postedWithinDays,
        featuredOnly: featuredOnly,
        query: newQuery,
        limit: limit,
      );

  /// Same query and category with the filter sheet's values (null clears each).
  AdsFilter withRefinements({
    int? cityId,
    int? districtId,
    String? adType,
    double? minPrice,
    double? maxPrice,
    int? postedWithinDays,
  }) =>
      AdsFilter(
        categoryId: categoryId,
        cityId: cityId,
        // A district only makes sense inside the chosen city.
        districtId: cityId == null ? null : districtId,
        adType: adType,
        minPrice: minPrice,
        maxPrice: maxPrice,
        postedWithinDays: postedWithinDays,
        featuredOnly: featuredOnly,
        query: query,
        limit: limit,
      );

  /// True when the search narrows what alerts can match (worth saving).
  /// The date window does not count: alerts are about new ads anyway.
  bool get hasCriteria =>
      (query?.trim().isNotEmpty ?? false) ||
      categoryId != null ||
      cityId != null ||
      districtId != null ||
      adType != null ||
      minPrice != null ||
      maxPrice != null;
}

/// Explore's filter as URL query parameters, so links, deep links and back
/// navigation carry the search. Only set values are written.
Map<String, String> adsFilterToQuery(AdsFilter f) {
  String num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  final q = f.query?.trim();
  return {
    if (q != null && q.isNotEmpty) 'q': q,
    if (f.categoryId != null) 'category': f.categoryId!,
    if (f.cityId != null) 'city': '${f.cityId}',
    if (f.districtId != null) 'district': '${f.districtId}',
    if (f.adType != null) 'type': f.adType!,
    if (f.minPrice != null) 'min': num(f.minPrice!),
    if (f.maxPrice != null) 'max': num(f.maxPrice!),
    if (f.postedWithinDays != null) 'days': '${f.postedWithinDays}',
    if (f.featuredOnly) 'featured': 'true',
  };
}

/// The filter a URL asks for, or null when it names none (plain /explore:
/// keep whatever search is open). Invalid values are ignored.
AdsFilter? adsFilterFromQuery(Map<String, String> params) {
  const keys = {'q', 'category', 'city', 'district', 'type', 'min', 'max', 'days', 'featured'};
  if (!params.keys.any(keys.contains)) return null;
  int? integer(String key) => int.tryParse(params[key] ?? '');
  double? decimal(String key) => double.tryParse(params[key] ?? '');
  final type = params['type'];
  final q = params['q']?.trim();
  final city = integer('city');
  return AdsFilter(
    query: (q == null || q.isEmpty) ? null : q,
    categoryId: integer('category')?.toString(),
    cityId: city,
    districtId: city == null ? null : integer('district'),
    adType: (type == 'offering' || type == 'seeking') ? type : null,
    minPrice: decimal('min'),
    maxPrice: decimal('max'),
    postedWithinDays: integer('days'),
    featuredOnly: params['featured'] == 'true',
  );
}

/// Same search (ignores paging).
bool sameSearch(AdsFilter a, AdsFilter b) {
  final x = adsFilterToQuery(a), y = adsFilterToQuery(b);
  return x.length == y.length && x.entries.every((e) => y[e.key] == e.value);
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
    if (f.districtId != null) 'p_district_id': f.districtId,
    if (f.postedWithinDays != null) 'p_posted_within_days': f.postedWithinDays,
    if (f.isNearMe) 'p_near_lat': f.nearLat,
    if (f.isNearMe) 'p_near_lng': f.nearLng,
    if (f.isNearMe && f.radiusKm != null) 'p_radius_km': f.radiusKm,
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

/// Explore's search (driven by the /explore URL).
final adsNotifierProvider = StateNotifierProvider<AdsNotifier, AdsState>((ref) {
  return AdsNotifier(ref.watch(supabaseClientProvider));
});

/// Home's "latest ads" feed, separate so a search never changes it.
final homeAdsNotifierProvider = StateNotifierProvider<AdsNotifier, AdsState>((ref) {
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

// Notifications providers live in features/notifications/providers.

/// Where a contact button leads once the seller's number is revealed:
/// `tel:` for a call, wa.me with a ready message naming the ad for WhatsApp.
Uri? sellerContactUri(String type, String phone, String adTitle) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  switch (type) {
    case 'phone':
      return Uri(scheme: 'tel', path: '+$digits');
    case 'whatsapp':
      return Uri.https('wa.me', '/$digits', {'text': 'مرحباً، بخصوص إعلانك "$adTitle" على وصلة'});
    default:
      return null;
  }
}

/// Reveals the seller's number through reveal_seller_phone, which also logs
/// the contact in contact_logs (review eligibility). Overridable in tests.
final sellerPhoneRevealerProvider = Provider<Future<SellerPhoneResult> Function(String adId, String contactType)>(
  (ref) => (adId, contactType) =>
      revealSellerPhone(client: ref.read(supabaseClientProvider), adId: adId, contactType: contactType),
);

/// Opens a tel: / https: link. Overridable in tests.
final externalLinkLauncherProvider = Provider<Future<void> Function(Uri uri)>((ref) => (uri) async {
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    });

