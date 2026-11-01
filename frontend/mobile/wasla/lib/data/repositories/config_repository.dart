import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client_provider.dart';

/// Public app settings (app_configs) and the legal documents' acceptance.
class ConfigRepository {
  ConfigRepository(this._client);

  final SupabaseClient _client;

  /// {key, value} rows for [keys].
  Future<List<Map<String, dynamic>>> configs(List<String> keys) async =>
      (await _client.from('app_configs').select('key, value').inFilter('key', keys)).cast<Map<String, dynamic>>();

  Future<Object?> legalStatus() => _client.rpc('legal_status');

  Future<Object?> acceptLegalDocuments({required int termsVersion, required int privacyVersion}) =>
      _client.rpc('accept_legal_documents', params: {
        'p_terms_version': termsVersion,
        'p_privacy_version': privacyVersion,
      });
}

final configRepositoryProvider = Provider<ConfigRepository>((ref) => ConfigRepository(ref.watch(supabaseClientProvider)));
