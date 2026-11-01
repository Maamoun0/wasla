import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/users_repository.dart';

// Fetch public profile of the seller
final sellerProfileProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>(
    (ref, userId) => ref.watch(usersRepositoryProvider).publicProfile(userId));

// Fetch active ads for a seller, joining with cities and ad_media to display thumbnails
final sellerActiveAdsProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>(
    (ref, userId) => ref.watch(usersRepositoryProvider).activeAdsOf(userId));

// Fetch reviews received by a seller, joining with reviewer info and seller's responses
final sellerReviewsProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>(
    (ref, userId) => ref.watch(usersRepositoryProvider).reviewsReceived(userId));
