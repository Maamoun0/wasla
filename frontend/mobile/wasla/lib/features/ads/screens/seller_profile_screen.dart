import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/trust_badge.dart';
import '../providers/seller_profile_provider.dart';

class SellerProfileScreen extends ConsumerWidget {
  const SellerProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(sellerProfileProvider(userId));
    final adsAsync = ref.watch(sellerActiveAdsProvider(userId));
    final reviewsAsync = ref.watch(sellerReviewsProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('ملف المعلن'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary600),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('فشل تحميل الملف الشخصي للمعلن', style: TextStyle(fontFamily: 'Cairo')),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(sellerProfileProvider(userId));
                  ref.invalidate(sellerActiveAdsProvider(userId));
                  ref.invalidate(sellerReviewsProvider(userId));
                },
                child: const Text('إعادة المحاولة'),
              )
            ],
          ),
        ),
        data: (profile) => DefaultTabController(
          length: 2,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: _buildProfileHeader(context, profile),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    indicatorColor: AppColors.primary600,
                    labelColor: AppColors.primary600,
                    unselectedLabelColor: AppColors.neutral500,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.grid_view_rounded, size: 18),
                            const SizedBox(width: 8),
                            adsAsync.when(
                              data: (ads) => Text('الإعلانات (${ads.length})'),
                              loading: () => const Text('الإعلانات (...)'),
                              error: (_, __) => const Text('الإعلانات'),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.rate_review_rounded, size: 18),
                            const SizedBox(width: 8),
                            reviewsAsync.when(
                              data: (reviews) => Text('التقييمات (${reviews.length})'),
                              loading: () => const Text('التقييمات (...)'),
                              error: (_, __) => const Text('التقييمات'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              children: [
                _buildAdsTab(context, adsAsync),
                _buildReviewsTab(context, reviewsAsync, profile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Profile Header Section ──
  Widget _buildProfileHeader(BuildContext context, Map<String, dynamic> profile) {
    final fullName = profile['full_name'] as String? ?? 'مستخدم وصلة';
    final bio = profile['bio'] as String? ?? 'لا يوجد نبذة شخصية حتى الآن.';
    final isVerified = profile['is_id_verified'] as bool? ?? false;
    final trustScore = double.tryParse(profile['trust_score']?.toString() ?? '0.00') ?? 0.00;
    
    // Format join date: e.g. يونيو 2026
    String joinDateStr = 'غير معروف';
    if (profile['created_at'] != null) {
      try {
        final parsedDate = DateTime.parse(profile['created_at']);
        joinDateStr = DateFormat('MMMM yyyy', 'ar').format(parsedDate);
      } catch (_) {
        joinDateStr = profile['created_at'].toString().split('T').first;
      }
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with Verification Badge Overlay
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.neutral100,
                backgroundImage: profile['avatar_url'] != null
                    ? CachedNetworkImageProvider(profile['avatar_url'])
                    : const AssetImage(AppAssets.avatar) as ImageProvider,
              ),
              if (isVerified)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: AppColors.primary600,
                    size: 24,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          
          Text(
            fullName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutral900,
                  fontFamily: 'Cairo',
                ),
          ),
          const SizedBox(height: AppSizes.sm),
          TrustBadge(trustScore: trustScore, isVerified: isVerified),
          const SizedBox(height: AppSizes.sm),
          
          // Member Since
          Text(
            'عضو منذ $joinDateStr',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.neutral500,
                ),
          ),
          const SizedBox(height: AppSizes.md),
          
          // Bio
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.neutral600,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Ads Grid ──
  Widget _buildAdsTab(BuildContext context, AsyncValue<List<Map<String, dynamic>>> adsAsync) {
    return adsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary600),
      ),
      error: (err, stack) => Center(
        child: Text('فشل تحميل الإعلانات: $err', style: const TextStyle(fontFamily: 'Cairo')),
      ),
      data: (ads) {
        if (ads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.feed_outlined, size: 64, color: AppColors.neutral300),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد إعلانات نشطة حالياً لهذا المعلن.',
                  style: TextStyle(fontFamily: 'Cairo', color: AppColors.neutral500),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(AppSizes.lg),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: ads.length,
          itemBuilder: (context, index) {
            final ad = ads[index];
            final price = double.tryParse(ad['price']?.toString() ?? '0') ?? 0;
            final priceType = ad['price_type'] as String? ?? 'fixed';
            final cityName = ad['cities'] != null ? ad['cities']['name_ar'] as String? ?? '' : '';
            
            // Extract thumbnail image url
            String? imageUrl;
            final mediaList = ad['ad_media'] as List?;
            if (mediaList != null && mediaList.isNotEmpty) {
              // Find primary or default to first
              final primary = mediaList.firstWhere((item) => item['is_primary'] == true, orElse: () => mediaList.first);
              imageUrl = primary['url'] as String?;
            }

            final isFeatured = ad['is_featured'] as bool? ?? false;
            final isUrgent = ad['is_urgent'] as bool? ?? false;

            return GestureDetector(
              onTap: () => context.push(AppRoutes.adDetail.replaceAll(':id', ad['id'].toString())),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ad image & badges
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: AppColors.neutral100),
                                  errorWidget: (context, url, error) => Image.asset(AppAssets.placeholder, fit: BoxFit.cover),
                                )
                              : Image.asset(AppAssets.placeholder, fit: BoxFit.cover),
                          
                          // Boost Feature Badges
                          if (isFeatured || isUrgent)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (isFeatured)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent500,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'مميز',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  if (isUrgent) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.error,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'عاجل',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Ad details
                    Padding(
                      padding: const EdgeInsets.all(AppSizes.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ad['title'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.neutral900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 12, color: AppColors.neutral400),
                              const SizedBox(width: 4),
                              Text(
                                cityName,
                                style: const TextStyle(fontSize: 11, color: AppColors.neutral500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          
                          // Price
                          Text(
                            priceType == 'free'
                                ? 'مجاناً'
                                : priceType == 'on_request'
                                    ? 'السعر عند الطلب'
                                    : '${NumberFormat('#,###').format(price)} ج.م',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: priceType == 'free' ? AppColors.success : AppColors.primary600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Tab 2: Reviews List ──
  Widget _buildReviewsTab(
    BuildContext context,
    AsyncValue<List<Map<String, dynamic>>> reviewsAsync,
    Map<String, dynamic> profile,
  ) {
    return reviewsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary600),
      ),
      error: (err, stack) => Center(
        child: Text('فشل تحميل التقييمات: $err', style: const TextStyle(fontFamily: 'Cairo')),
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rate_review_outlined, size: 64, color: AppColors.neutral300),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد تقييمات لهذا المعلن بعد.',
                  style: TextStyle(fontFamily: 'Cairo', color: AppColors.neutral500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.lg),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index];
            final rating = review['rating'] as int? ?? 5;
            final comment = review['comment'] as String? ?? '';
            final reviewer = review['reviewer'] as Map<String, dynamic>?;
            final reviewerName = reviewer != null ? reviewer['full_name'] as String? ?? 'مشتري وصلة' : 'مشتري وصلة';
            final reviewerAvatar = reviewer != null ? reviewer['avatar_url'] as String? : null;

            String reviewDateStr = '';
            if (review['created_at'] != null) {
              try {
                final date = DateTime.parse(review['created_at']);
                reviewDateStr = DateFormat('yyyy/MM/dd').format(date);
              } catch (_) {}
            }

            // Extract Response if exists
            final responseList = review['review_responses'] as List?;
            final sellerResponse = responseList != null && responseList.isNotEmpty
                ? responseList.first['response'] as String?
                : null;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                side: const BorderSide(color: AppColors.neutral200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reviewer Header Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.neutral100,
                          backgroundImage: reviewerAvatar != null
                              ? CachedNetworkImageProvider(reviewerAvatar)
                              : const AssetImage(AppAssets.avatar) as ImageProvider,
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reviewerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                reviewDateStr,
                                style: const TextStyle(color: AppColors.neutral500, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        
                        // Review Stars
                        Row(
                          children: List.generate(5, (starIdx) {
                            return Icon(
                              Icons.star_rounded,
                              color: starIdx < rating ? AppColors.accent500 : AppColors.neutral300,
                              size: 16,
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    
                    // Review Content
                    if (comment.isNotEmpty)
                      Text(
                        comment,
                        style: const TextStyle(
                          color: AppColors.neutral700,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      
                    // Seller nested response card
                    if (sellerResponse != null) ...[
                      const SizedBox(height: AppSizes.md),
                      Container(
                        padding: const EdgeInsets.all(AppSizes.md),
                        decoration: BoxDecoration(
                          color: AppColors.accent50.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accent100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.reply_rounded, color: AppColors.accent600, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'رد المعلن:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.accent800,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sellerResponse,
                              style: const TextStyle(
                                color: AppColors.neutral700,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Persistent Tab Bar Delegate ──
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
