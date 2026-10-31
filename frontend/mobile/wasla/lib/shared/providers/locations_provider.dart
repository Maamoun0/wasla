import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';

// Governorates, cities and districts (active only, Arabic order).
final governoratesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('governorates')
      .select()
      .eq('is_active', true)
      .order('name_ar');
  return (response as List).cast<Map<String, dynamic>>();
});

final citiesProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, govId) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('cities')
      .select()
      .eq('governorate_id', govId)
      .eq('is_active', true)
      .order('name_ar');
  return (response as List).cast<Map<String, dynamic>>();
});

final districtsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, cityId) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('districts')
      .select()
      .eq('city_id', cityId)
      .order('name_ar');
  return (response as List).cast<Map<String, dynamic>>();
});

/// One city with its governorate, to reopen a filter on an already chosen city.
final cityByIdProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, cityId) async {
  final client = ref.watch(supabaseClientProvider);
  return await client.from('cities').select('id, governorate_id, name_ar').eq('id', cityId).maybeSingle();
});
