import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_utils.dart';

/// Widget موحَّد لعرض صور الإعلانات مع placeholder وتحجيم تلقائي.
/// يستخدم ImageUtils.thumbnail() للقوائم تلقائياً.
class WaslaImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool useThumbnail;

  const WaslaImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.useThumbnail = true,
  });

  @override
  Widget build(BuildContext context) {
    final url = (useThumbnail && imageUrl.isNotEmpty)
        ? ImageUtils.thumbnail(imageUrl)
        : imageUrl;

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Container(
        color: const Color(0xFFF3F4F6),
        child: const Center(
          child: Icon(Icons.image_outlined, color: Color(0xFFD1D5DB), size: 32),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFFF3F4F6),
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Color(0xFFD1D5DB), size: 32),
        ),
      ),
    );
  }
}
