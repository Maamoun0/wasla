import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/payments_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/supabase/function_errors.dart';

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
  final PaymentsRepository _repository;
  final String? _userId;

  BoostController(this._repository, this._userId) : super(BoostState()) {
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
      final ads = await _repository.activeAdsWithBoosts(_userId);
      
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

  // Boost packages and their prices come from public.payment_packages,
  // the same table create-payment charges from.
  Future<void> fetchPackages() async {
    final packages = (await _repository.boostPackages()).map((item) => BoostPackage(
          key: item['id'] as String,
          price: (item['price_egp'] as num).toDouble(),
          nameAr: item['name_ar'] as String,
          type: item['boost_type'] as String,
          durationDays: item['duration_days'] as int,
        ));
    state = state.copyWith(packages: packages.toList());
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
      final response = await _repository.adBoostStatus(ad['id']);

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
      final checkout = await _repository.createPayment({'package_id': package.key, 'ad_id': ad['id']});

      state = state.copyWith(isVerifying: false);

      return checkout;

    } catch (e) {
      // A refusal from create-payment (FunctionException) carries its own message.
      state = state.copyWith(
        isVerifying: false,
        errorMessage: () => functionErrorMessage(e, fallback: 'حدث خطأ في الاتصال بالخادم، يرجى المحاولة لاحقاً'),
      );
      return null;
    }
  }
}

final boostControllerProvider = StateNotifierProvider.autoDispose<BoostController, BoostState>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return BoostController(ref.watch(paymentsRepositoryProvider), userId);
});
