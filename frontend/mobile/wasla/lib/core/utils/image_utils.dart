/// Image URLs for display (NFR-1.2).
///
/// Photos are stored once in Supabase Storage. Resized, compressed versions
/// (WebP when the device accepts it) come from the image transformation
/// endpoint `/storage/v1/render/image/public/…`. The plain object URL
/// `/storage/v1/object/public/…` ignores width/quality and always returns the
/// full file, which lists used to download.
class ImageUtils {
  static const _objectPath = '/storage/v1/object/public/';
  static const _renderPath = '/storage/v1/render/image/public/';

  /// للبطاقات والقوائم — صورة صغيرة مضغوطة
  static String thumbnail(String originalUrl, {int width = 400}) =>
      _render(originalUrl, {'width': '$width', 'quality': '70'});

  /// لشاشة التفاصيل — مقاس كبير بجودة عالية، بس مضغوط
  static String fullQuality(String originalUrl) => _render(originalUrl, {'width': '1600', 'quality': '80'});

  /// Our Storage URLs go through the render endpoint; any other URL (or a
  /// malformed one) is returned unchanged. Existing query parameters (e.g.
  /// the avatar's `?v=` cache buster) are kept.
  static String _render(String url, Map<String, String> params) {
    if (url.isEmpty || !url.contains(_objectPath)) return url;
    final uri = Uri.tryParse(url.replaceFirst(_objectPath, _renderPath));
    if (uri == null) return url;
    return uri.replace(queryParameters: {...uri.queryParameters, ...params}).toString();
  }
}
