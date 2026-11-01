import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/payments_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/supabase/function_errors.dart';

enum SubscriptionScreenStatus { idle, loading, success, error }

class SubscriptionState {
  final SubscriptionScreenStatus status;
  final String? errorMessage;
  final List<Map<String, dynamic>> plans;
  final Map<String, dynamic>? activeSubscription;
  final bool isVerifying;

  SubscriptionState({
    this.status = SubscriptionScreenStatus.idle,
    this.errorMessage,
    this.plans = const [],
    this.activeSubscription,
    this.isVerifying = false,
  });

  SubscriptionState copyWith({
    SubscriptionScreenStatus? status,
    String? Function()? errorMessage,
    List<Map<String, dynamic>>? plans,
    Map<String, dynamic>? Function()? activeSubscription,
    bool? isVerifying,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      plans: plans ?? this.plans,
      activeSubscription: activeSubscription != null ? activeSubscription() : this.activeSubscription,
      isVerifying: isVerifying ?? this.isVerifying,
    );
  }
}

class SubscriptionController extends StateNotifier<SubscriptionState> {
  final PaymentsRepository _repository;
  final String? _userId;

  SubscriptionController(this._repository, this._userId) : super(SubscriptionState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(status: SubscriptionScreenStatus.loading);
    try {
      await Future.wait([
        fetchPlans(),
        fetchActiveSubscription(),
      ]);
      state = state.copyWith(status: SubscriptionScreenStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: SubscriptionScreenStatus.error,
        errorMessage: () => 'فشل تحميل باقات الاشتراك المتاحة',
      );
    }
  }

  // Fetch plans from subscription_plans table ordered by sort_order
  Future<void> fetchPlans() async {
    try {
      state = state.copyWith(plans: await _repository.subscriptionPlans());
    } catch (e) {
      rethrow;
    }
  }

  // Fetch the user's active subscription from user_subscriptions table
  Future<void> fetchActiveSubscription() async {
    if (_userId == null) return;
    try {
      final response = await _repository.activeSubscription(_userId);

      state = state.copyWith(activeSubscription: () => response);
    } catch (e) {
      // It is completely fine if there's no active subscription, it will return null
      state = state.copyWith(activeSubscription: () => null);
    }
  }

  // Check if the user has a paid active subscription
  bool hasActivePaidSubscription() {
    final activeSub = state.activeSubscription;
    if (activeSub == null) return false;

    // Check if the plan is paid
    final planId = activeSub['plan_id'] as num?;
    // planId = 1 is the 'free' plan according to wasla-schema.sql seed data
    return planId != null && planId != 1;
  }

  // Call serverless create-payment stub
  Future<Map<String, dynamic>?> prepareUpgrade(Map<String, dynamic> selectedPlan) async {
    if (_userId == null) return null;
    state = state.copyWith(isVerifying: true, errorMessage: () => null);

    try {
      final package = monthlyPackageOf(selectedPlan);
      if (package == null) {
        state = state.copyWith(
          isVerifying: false,
          errorMessage: () => 'هذه الباقة غير متاحة للشراء حالياً',
        );
        return null;
      }

      final checkout = await _repository.createPayment({'package_id': package['id']});

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

/// The active 30-day package attached to a plan row, if any.
Map<String, dynamic>? monthlyPackageOf(Map<String, dynamic> plan) {
  final packages = (plan['payment_packages'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  for (final p in packages) {
    if (p['duration_days'] == 30) return p;
  }
  return null;
}

final subscriptionControllerProvider = StateNotifierProvider.autoDispose<SubscriptionController, SubscriptionState>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return SubscriptionController(ref.watch(paymentsRepositoryProvider), userId);
});
