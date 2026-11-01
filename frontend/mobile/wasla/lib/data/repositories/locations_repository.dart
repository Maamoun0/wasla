import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client_provider.dart';

/// Governorates, cities and districts (active only, Arabic order).
class LocationsRepository {
  LocationsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> governorates() async =>
      (await _client.from('governorates').select().eq('is_active', true).order('name_ar')).cast<Map<String, dynamic>>();

  Future<List<Map<String, dynamic>>> cities(int governorateId) async => (await _client
          .from('cities')
          .select()
          .eq('governorate_id', governorateId)
          .eq('is_active', true)
          .order('name_ar'))
      .cast<Map<String, dynamic>>();

  Future<List<Map<String, dynamic>>> districts(int cityId) async =>
      (await _client.from('districts').select().eq('city_id', cityId).order('name_ar')).cast<Map<String, dynamic>>();

  /// One city with its governorate, to reopen a filter on an already chosen city.
  Future<Map<String, dynamic>?> city(int cityId) =>
      _client.from('cities').select('id, governorate_id, name_ar').eq('id', cityId).maybeSingle();
}

final locationsRepositoryProvider =
    Provider<LocationsRepository>((ref) => LocationsRepository(ref.watch(supabaseClientProvider)));
