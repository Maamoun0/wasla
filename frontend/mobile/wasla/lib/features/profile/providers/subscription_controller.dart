import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

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
  final SupabaseClient _client;
  final String? _userId;

  SubscriptionController(this._client, this._userId) : super(SubscriptionState()) {
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
      final response = await _client
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      state = state.copyWith(plans: List<Map<String, dynamic>>.from(response));
    } catch (e) {
      rethrow;
    }
  }

  // Fetch the user's active subscription from user_subscriptions table
  Future<void> fetchActiveSubscription() async {
    if (_userId == null) return;
    try {
      final response = await _client
          .from('user_subscriptions')
          .select('*, subscription_plans(name, name_ar)')
          .eq('user_id', _userId)
          .eq('status', 'active')
          .maybeSingle();

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
      final price = (selectedPlan['price_monthly'] as num?)?.toDouble() ?? 0.0;
      
      final functionResponse = await _client.functions.invoke(
        'create-payment',
        body: {
          'type': 'subscription',
          'reference_id': selectedPlan['id'].toString(),
          'amount': price,
          'payment_method': 'card', // default method for Sandbox
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

final subscriptionControllerProvider = StateNotifierProvider.autoDispose<SubscriptionController, SubscriptionState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  return SubscriptionController(client, userId);
});
