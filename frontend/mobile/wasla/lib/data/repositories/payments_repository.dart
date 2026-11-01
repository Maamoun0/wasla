import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client_provider.dart';

/// Boosts, subscriptions and the create-payment function.
class PaymentsRepository {
  PaymentsRepository(this._client);

  final SupabaseClient _client;

  /// The user's active ads with their boosts.
  Future<List<Map<String, dynamic>>> activeAdsWithBoosts(String userId) async => List<Map<String, dynamic>>.from(
      await _client.from('ads').select('*, ad_boosts(expires_at, boost_type)').eq('user_id', userId).eq('status', 'active'));

  /// Boost packages and prices, from the table create-payment charges from.
  Future<List<Map<String, dynamic>>> boostPackages() async => List<Map<String, dynamic>>.from(await _client
      .from('payment_packages')
      .select('id, name_ar, price_egp, boost_type, duration_days')
      .eq('kind', 'ad_boost')
      .eq('is_active', true)
      .order('price_egp', ascending: true));

  /// Fresh status and boosts of one ad, right before paying.
  Future<Map<String, dynamic>?> adBoostStatus(Object adId) =>
      _client.from('ads').select('status, id, ad_boosts(expires_at)').eq('id', adId).maybeSingle();

  /// Each plan carries its purchasable package (price charged by create-payment).
  Future<List<Map<String, dynamic>>> subscriptionPlans() async => List<Map<String, dynamic>>.from(await _client
      .from('subscription_plans')
      .select('*, payment_packages(id, price_egp, duration_days)')
      .eq('is_active', true)
      .order('sort_order', ascending: true));

  Future<Map<String, dynamic>?> activeSubscription(String userId) => _client
      .from('user_subscriptions')
      .select('*, subscription_plans(name, name_ar)')
      .eq('user_id', userId)
      .eq('status', 'active')
      .maybeSingle();

  /// Calls [onStatus] with each new status of one transaction (Realtime).
  /// Pass the result to [stopWatching] when done.
  RealtimeChannel watchTransaction(String transactionId, void Function(String? status) onStatus) => _client
      .channel('public:transactions:id=eq.$transactionId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'transactions',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: transactionId),
        callback: (payload) => onStatus(payload.newRecord['status'] as String?),
      )
      .subscribe();

  Future<void> stopWatching(RealtimeChannel channel) => _client.removeChannel(channel);

  /// create-payment's answer (the Paymob checkout). Refusals throw FunctionException.
  Future<Map<String, dynamic>> createPayment(Map<String, dynamic> body) async =>
      (await _client.functions.invoke('create-payment', body: body)).data as Map<String, dynamic>;
}

final paymentsRepositoryProvider =
    Provider<PaymentsRepository>((ref) => PaymentsRepository(ref.watch(supabaseClientProvider)));
