
abstract class AdsRepository {
  /// جلب الإعلانات المميزة (Featured Ads)
  Future<List<Map<String, dynamic>>> getFeaturedAds({int limit = 10});

  /// جلب الإعلانات القريبة من العميل بناءً على موقعه الجغرافي
  Future<List<Map<String, dynamic>>> getNearbyAds({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    int limit = 20,
  });

  /// جلب شجرة الأقسام (Categories)
  Future<List<Map<String, dynamic>>> getCategories({int? parentId});

  /// البحث عن الإعلانات مع الفلاتر والكلمات المفتاحية
  Future<List<Map<String, dynamic>>> searchAds({
    required String query,
    Map<String, dynamic>? filters,
    int limit = 20,
    int offset = 0,
  });

  /// جلب تفاصيل إعلان معين بالمعرف الخاص به
  Future<Map<String, dynamic>> getAdDetails(String adId);

  /// إضافة إعلان للمفضلة
  Future<void> addToFavorites(String adId);

  /// إزالة إعلان من المفضلة
  Future<void> removeFromFavorites(String adId);

  /// الحصول على قائمة الإعلانات المفضلة الحالية للمستخدم
  Future<List<Map<String, dynamic>>> getFavoriteAds();

  /// تسجيل عملية تواصل (اتصال، واتساب، إيميل) مع البائع لزيادة التحليلات
  Future<void> logContact(String adId, String contactType);

  /// نشر إعلان جديد بالكامل
  Future<String> createAd(Map<String, dynamic> adData);

  /// تحديث حالة الإعلان (نشط، مؤقت، مباع، إلخ)
  Future<void> updateAdStatus(String adId, String status);
}
