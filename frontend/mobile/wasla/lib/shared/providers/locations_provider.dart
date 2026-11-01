import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/locations_repository.dart';

// Governorates, cities and districts (active only, Arabic order).
final governoratesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) => ref.watch(locationsRepositoryProvider).governorates());

final citiesProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
    (ref, govId) => ref.watch(locationsRepositoryProvider).cities(govId));

final districtsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
    (ref, cityId) => ref.watch(locationsRepositoryProvider).districts(cityId));

/// One city with its governorate, to reopen a filter on an already chosen city.
final cityByIdProvider = FutureProvider.family<Map<String, dynamic>?, int>(
    (ref, cityId) => ref.watch(locationsRepositoryProvider).city(cityId));
