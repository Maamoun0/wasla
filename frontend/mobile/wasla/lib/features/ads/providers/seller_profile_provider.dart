import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

// Fetch public profile of the seller
final sellerProfileProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, userId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('users')
      .select('id, full_name, avatar_url, bio, trust_score, is_id_verified, created_at, city_id')
      .eq('id', userId)
      .single();
  return response;
});

// Fetch active ads for a seller, joining with cities and ad_media to display thumbnails
final sellerActiveAdsProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, userId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('ads')
      .select('id, title, price, price_type, created_at, is_featured, is_urgent, cities(name_ar), ad_media(url, is_primary)')
      .eq('user_id', userId)
      .eq('status', 'active')
      .order('created_at', ascending: false);
      
  return List<Map<String, dynamic>>.from(response);
});

// Fetch reviews received by a seller, joining with reviewer info and seller's responses
final sellerReviewsProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, userId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('reviews')
      .select('id, rating, comment, created_at, reviewer:reviewer_id(full_name, avatar_url), review_responses(response, created_at)')
      .eq('reviewed_user_id', userId)
      .eq('status', 'active')
      .order('created_at', ascending: false);
      
  return List<Map<String, dynamic>>.from(response);
});
