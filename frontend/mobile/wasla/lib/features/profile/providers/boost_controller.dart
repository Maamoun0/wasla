import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

enum BoostScreenStatus { idle, loading, success, error }

class BoostPackage {
  final String key;
  final double price;
  final String nameAr;
  final String type; // 'featured', 'urgent', 'bump'
  final int durationDays;

  BoostPackage({
    required this.key,
    required this.price,
    required this.nameAr,
    required this.type,
    required this.durationDays,
  });
}

class BoostState {
  final BoostScreenStatus status;
  final String? errorMessage;
  final List<Map<String, dynamic>> userAds;
  final List<BoostPackage> packages;
  final Map<String, dynamic>? selectedAd;
  final BoostPackage? selectedPackage;
  final bool isVerifying;

  BoostState({
    this.status = BoostScreenStatus.idle,
    this.errorMessage,
    this.userAds = const [],
    this.packages = const [],
    this.selectedAd,
    this.selectedPackage,
    this.isVerifying = false,
  });

  BoostState copyWith({
    BoostScreenStatus? status,
    String? Function()? errorMessage,
    List<Map<String, dynamic>>? userAds,
    List<BoostPackage>? packages,
    Map<String, dynamic>? Function()? selectedAd,
    BoostPackage? Function()? selectedPackage,
    bool? isVerifying,
  }) {
    return BoostState(
      status: status ?? this.status,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      userAds: userAds ?? this.userAds,
      packages: packages ?? this.packages,
      selectedAd: selectedAd != null ? selectedAd() : this.selectedAd,
      selectedPackage: selectedPackage != null ? selectedPackage() : this.selectedPackage,
      isVerifying: isVerifying ?? this.isVerifying,
    );
  }
}

class BoostController extends StateNotifier<BoostState> {
  final SupabaseClient _client;
  final String? _userId;

  BoostController(this._client, this._userId) : super(BoostState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(status: BoostScreenStatus.loading);
    try {
      await Future.wait([
        fetchPackages(),
        fetchUserEligibleAds(),
      ]);
      state = state.copyWith(status: BoostScreenStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: BoostScreenStatus.error,
        errorMessage: () => 'فشل تحميل البيانات الترويجية',
      );
    }
  }

  // Fetch active ads from the database that are eligible for boosting
  Future<void> fetchUserEligibleAds() async {
    if (_userId == null) return;
    try {
      final response = await _client
          .from('ads')
          .select('*, ad_boosts(expires_at, boost_type)')
          .eq('user_id', _userId)
          .eq('status', 'active');

      final List<Map<String, dynamic>> ads = List<Map<String, dynamic>>.from(response);
      
      // Filter ads locally: keep only those whose boosts have expired or have no boost
      final now = DateTime.now();
      final eligibleAds = ads.where((ad) {
        final boosts = ad['ad_boosts'] as List?;
        if (boosts == null || boosts.isEmpty) return true;

        // Check if there is any active boost (expires_at in the future)
        final hasActiveBoost = boosts.any((boost) {
          final expiresAtStr = boost['expires_at'] as String?;
          if (expiresAtStr == null) return false;
          final expiresAt = DateTime.parse(expiresAtStr);
          return expiresAt.isAfter(now);
        });

        return !hasActiveBoost;
      }).toList();

      state = state.copyWith(userAds: eligibleAds);
    } catch (e) {
      rethrow;
    }
  }

  // Fetch package configurations dynamically from public.app_configs
  Future<void> fetchPackages() async {
    try {
      final response = await _client
          .from('app_configs')
          .select()
          .like('key', 'boost_%');

      final List<BoostPackage> parsedPackages = [];
      
      for (final item in response) {
        final key = item['key'] as String;
        final value = double.tryParse(item['value'] as String? ?? '0') ?? 0.0;

        String nameAr = 'باقة الترقية';
        String type = 'bump';
        int durationDays = 1;

        if (key == 'boost_featured_3d') {
          nameAr = 'إعلان مميز (3 أيام)';
          type = 'featured';
          durationDays = 3;
        } else if (key == 'boost_featured_7d') {
          nameAr = 'إعلان مميز (7 أيام)';
          type = 'featured';
          durationDays = 7;
        } else if (key == 'boost_featured_14d') {
          nameAr = 'إعلان مميز (14 يوم)';
          type = 'featured';
          durationDays = 14;
        } else if (key == 'boost_featured_30d') {
          nameAr = 'إعلان مميز (30 يوم)';
          type = 'featured';
          durationDays = 30;
        } else if (key == 'boost_urgent_7d') {
          nameAr = 'إعلان عاجل (7 أيام)';
          type = 'urgent';
          durationDays = 7;
        } else if (key == 'boost_bump') {
          nameAr = 'تحديث الترتيب (Bump)';
          type = 'bump';
          durationDays = 1;
        } else {
          continue; // Skip other configurations
        }

        parsedPackages.add(BoostPackage(
          key: key,
          price: value,
          nameAr: nameAr,
          type: type,
          durationDays: durationDays,
        ));
      }

      // Sort by price ascending
      parsedPackages.sort((a, b) => a.price.compareTo(b.price));
      state = state.copyWith(packages: parsedPackages);
    } catch (e) {
      rethrow;
    }
  }

  void selectAd(Map<String, dynamic>? ad) {
    state = state.copyWith(selectedAd: () => ad);
  }

  void selectPackage(BoostPackage? package) {
    state = state.copyWith(selectedPackage: () => package);
  }

  // Pre-transition status verification before calling payment stub
  Future<Map<String, dynamic>?> verifyAndPreparePayment() async {
    final ad = state.selectedAd;
    final package = state.selectedPackage;

    if (ad == null || package == null) {
      state = state.copyWith(errorMessage: () => 'يرجى اختيار إعلان وباقة ترويجية أولاً');
      return null;
    }

    state = state.copyWith(isVerifying: true, errorMessage: () => null);

    try {
      // 1. Fresh database query check (lightweight SELECT status, boost_expires_at)
      final response = await _client
          .from('ads')
          .select('status, id, ad_boosts(expires_at)')
          .eq('id', ad['id'])
          .maybeSingle();

      if (response == null) {
        state = state.copyWith(
          isVerifying: false,
          errorMessage: () => 'عذراً، الإعلان غير موجود في النظام',
        );
        return null;
      }

      final status = response['status'] as String?;
      if (status != 'active') {
        state = state.copyWith(
          isVerifying: false,
          errorMessage: () => 'عذراً، لا يمكن ترويج هذا الإعلان لأنه غير نشط حالياً',
        );
        return null;
      }

      // Check if ad was boosted in the meantime
      final boosts = response['ad_boosts'] as List?;
      if (boosts != null && boosts.isNotEmpty) {
        final now = DateTime.now();
        final hasActiveBoost = boosts.any((boost) {
          final expiresAtStr = boost['expires_at'] as String?;
          if (expiresAtStr == null) return false;
          final expiresAt = DateTime.parse(expiresAtStr);
          return expiresAt.isAfter(now);
        });

        if (hasActiveBoost) {
          state = state.copyWith(
            isVerifying: false,
            errorMessage: () => 'هذا الإعلان تم ترويجه بالفعل من جلسة أخرى',
          );
          return null;
        }
      }

      // 2. Call the serverless create-payment stub
      final functionResponse = await _client.functions.invoke(
        'create-payment',
        body: {
          'type': 'ad_boost',
          'reference_id': ad['id'],
          'amount': package.price,
          'payment_method': 'card', // default method for Sandbox
          'metadata': {
            'boost_package_key': package.key,
            'boost_type': package.type,
            'duration_days': package.durationDays,
          }
        },
      );

      state = state.copyWith(isVerifying: false);

      if (functionResponse.status != 200) {
        final errorMsg = functionResponse.data is Map
            ? (functionResponse.data['error'] ?? 'فشل تهيئة بوابة الدفع')
            : 'فشل تهيئة بوابة الدفع';
        state = state.copyWith(errorMessage: () => errorMsg);
        return null;
      }

      return functionResponse.data as Map<String, dynamic>;

    } catch (e) {
      state = state.copyWith(
        isVerifying: false,
        errorMessage: () => 'حدث خطأ في الاتصال بالخادم، يرجى المحاولة لاحقاً',
      );
      return null;
    }
  }
}

final boostControllerProvider = StateNotifierProvider.autoDispose<BoostController, BoostState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  return BoostController(client, userId);
});
