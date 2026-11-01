import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/core/utils/image_utils.dart';

void main() {
  const object = 'https://abc.supabase.co/storage/v1/object/public/ads/u1/d1/0.jpg';

  test('Storage photos go through the render endpoint with size and quality (NFR-1.2)', () {
    expect(ImageUtils.thumbnail(object, width: 200),
        'https://abc.supabase.co/storage/v1/render/image/public/ads/u1/d1/0.jpg?width=200&quality=70');
    expect(ImageUtils.fullQuality(object),
        'https://abc.supabase.co/storage/v1/render/image/public/ads/u1/d1/0.jpg?width=1600&quality=80');
  });

  test('existing query parameters (avatar cache buster) are kept', () {
    final url = ImageUtils.thumbnail('https://abc.supabase.co/storage/v1/object/public/avatars/u1/avatar.jpg?v=123');
    expect(Uri.parse(url).queryParameters, {'v': '123', 'width': '400', 'quality': '70'});
  });

  test('other URLs are left alone', () {
    expect(ImageUtils.thumbnail('https://example.com/a.jpg'), 'https://example.com/a.jpg');
    expect(ImageUtils.thumbnail(''), '');
  });
}
