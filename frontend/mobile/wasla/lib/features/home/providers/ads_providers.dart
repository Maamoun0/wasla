import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/repositories/supabase_ads_repository.dart';
import '../domain/repositories/ads_repository.dart';

/// موفر مستودع الإعلانات
final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAdsRepository(client);
});

/// موفر قائمة الأقسام الرئيسية (المستوى 1)
final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adsRepositoryProvider);
  return repo.getCategories();
});

/// موفر الإعلانات المميزة للرئيسية
final featuredAdsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adsRepositoryProvider);
  return repo.getFeaturedAds(limit: 10);
});

/// موفر قائمة الإعلانات المفضلة للمستخدم الحالي
final favoriteAdsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adsRepositoryProvider);
  // نراقب حالة الدخول/الخروج لإعادة تحميل المفضلة عند تغيير الحساب
  final authUser = ref.watch(currentUserProvider);
  if (authUser == null) return [];
  return repo.getFavoriteAds();
});
