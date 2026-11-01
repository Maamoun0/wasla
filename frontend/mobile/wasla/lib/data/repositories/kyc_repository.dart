import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client_provider.dart';

/// Identity verification (FR-1.4).
class KycRepository {
  KycRepository(this._client);

  final SupabaseClient _client;

  /// The user's latest national-ID request, or null.
  Future<Map<String, dynamic>?> latestRequest(String userId) async {
    final rows = await _client
        .from('user_verifications')
        // Explicit columns: the HMAC and code hash are not readable by clients.
        .select('id, status, created_at, decided_at, national_id_last4, rejection_reason')
        .eq('user_id', userId)
        .eq('type', 'national_id')
        .order('created_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Sends the request to submit-kyc-request. Refusals throw FunctionException.
  Future<void> submit(Map<String, dynamic> body) => _client.functions.invoke('submit-kyc-request', body: body);
}

final kycRepositoryProvider = Provider<KycRepository>((ref) => KycRepository(ref.watch(supabaseClientProvider)));
