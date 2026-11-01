import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client_provider.dart';

/// Public profiles and reviews.
class UsersRepository {
  UsersRepository(this._client);

  final SupabaseClient _client;

  static const _receivedReviewSelect =
      'id, rating, comment, created_at, reviewer:reviewer_id(full_name, avatar_url), review_responses(response, created_at)';
  static const _sentReviewSelect =
      'id, rating, comment, created_at, reviewed:reviewed_user_id(full_name, avatar_url), review_responses(response, created_at)';

  Future<Map<String, dynamic>> publicProfile(String userId) => _client
      .from('users')
      .select('id, full_name, avatar_url, bio, trust_score, is_id_verified, created_at, city_id')
      .eq('id', userId)
      .single();

  /// A seller's active ads, with city and photos for the thumbnails.
  Future<List<Map<String, dynamic>>> activeAdsOf(String userId) async => List<Map<String, dynamic>>.from(await _client
      .from('ads')
      .select('id, title, price, price_type, created_at, is_featured, is_urgent, cities(name_ar), ad_media(url, is_primary)')
      .eq('user_id', userId)
      .eq('status', 'active')
      .order('created_at', ascending: false));

  /// Active reviews [userId] received, newest first; [from] and [to] page them.
  Future<List<Map<String, dynamic>>> reviewsReceived(String userId, {int? from, int? to}) async {
    final query = _client
        .from('reviews')
        .select(_receivedReviewSelect)
        .eq('reviewed_user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(await (from != null && to != null ? query.range(from, to) : query));
  }

  /// Active reviews [userId] wrote, newest first.
  Future<List<Map<String, dynamic>>> reviewsSent(String userId, {required int from, required int to}) async =>
      List<Map<String, dynamic>>.from(await _client
          .from('reviews')
          .select(_sentReviewSelect)
          .eq('reviewer_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .range(from, to));

  Future<void> replyToReview({required String reviewId, required String userId, required String response}) =>
      _client.from('review_responses').insert({'review_id': reviewId, 'user_id': userId, 'response': response});
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) => UsersRepository(ref.watch(supabaseClientProvider)));
