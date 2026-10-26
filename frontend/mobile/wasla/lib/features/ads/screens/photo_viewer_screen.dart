import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

// FutureProvider to dynamically fetch image URLs for a specific ad ID
final adMediaUrlsProvider = FutureProvider.family.autoDispose<List<String>, String>((ref, adId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('ad_media')
      .select('url')
      .eq('ad_id', adId)
      .order('sort_order', ascending: true);

  if (response.isEmpty) {
    return [];
  }
  return response.map<String>((media) => media['url'] as String).toList();
});

class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.adId,
    this.initialIndex = 0,
  });

  final String adId;
  final int initialIndex;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrlsAsync = ref.watch(adMediaUrlsProvider(widget.adId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: mediaUrlsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary500),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'فشل تحميل الصور',
                style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.refresh(adMediaUrlsProvider(widget.adId)),
                child: const Text('إعادة المحاولة', style: TextStyle(color: AppColors.primary200)),
              ),
            ],
          ),
        ),
        data: (urls) {
          if (urls.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_not_supported_rounded, size: 64, color: AppColors.neutral500),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد صور لهذا الإعلان',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('رجوع', style: TextStyle(color: AppColors.primary200)),
                  ),
                ],
              ),
            );
          }

          // In case initialIndex is out of range due to data updates
          final safeIndex = _currentIndex < urls.length ? _currentIndex : 0;

          return Stack(
            alignment: Alignment.center,
            children: [
              // ── Image Gallery View ─────────────────────────────────
              PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                builder: (BuildContext context, int index) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: CachedNetworkImageProvider(urls[index]),
                    initialScale: PhotoViewComputedScale.contained,
                    minScale: PhotoViewComputedScale.contained * 0.8,
                    maxScale: PhotoViewComputedScale.covered * 2.5,
                    heroAttributes: PhotoViewHeroAttributes(tag: '${widget.adId}_$index'),
                  );
                },
                itemCount: urls.length,
                loadingBuilder: (context, event) => Center(
                  child: SizedBox(
                    width: 30.0,
                    height: 30.0,
                    child: CircularProgressIndicator(
                      value: event == null
                          ? 0
                          : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                      color: AppColors.primary500,
                    ),
                  ),
                ),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                pageController: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),

              // ── Top Bar (Close and Indicators) ──────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close circular button
                    Material(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    
                    // Page indicator e.g. "3 / 8"
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${safeIndex + 1} / ${urls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    
                    // Spacer to keep layout balanced
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // ── Left/Right Swipe Guidance Arrows (Visual Help) ─────
              if (urls.length > 1) ...[
                if (safeIndex > 0)
                  Positioned(
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70),
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      ),
                    ),
                  ),
                if (safeIndex < urls.length - 1)
                  Positioned(
                    left: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
                        onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
