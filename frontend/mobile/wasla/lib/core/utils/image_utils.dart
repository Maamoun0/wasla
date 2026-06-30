class ImageUtils {
  /// للبطاقات والقوائم — جودة مضغوطة
  static String thumbnail(String originalUrl, {int width = 400}) {
    if (originalUrl.isEmpty) return originalUrl;
    // Check if the URL already has parameters
    final separator = originalUrl.contains('?') ? '&' : '?';
    return '$originalUrl${separator}width=$width&quality=70';
  }

  /// لشاشة التفاصيل — الجودة الكاملة
  static String fullQuality(String originalUrl) {
    return originalUrl; // بدون تعديل
  }
}
