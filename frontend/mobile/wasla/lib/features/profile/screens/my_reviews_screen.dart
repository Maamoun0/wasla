import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/reviews_controller.dart';

class MyReviewsScreen extends ConsumerStatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  ConsumerState<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends ConsumerState<MyReviewsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _receivedScrollController = ScrollController();
  final ScrollController _sentScrollController = ScrollController();
  final TextEditingController _replyTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _receivedScrollController.addListener(() {
      if (_receivedScrollController.position.pixels >=
          _receivedScrollController.position.maxScrollExtent - 200) {
        ref.read(reviewsControllerProvider.notifier).fetchReceivedReviews(isLoadMore: true);
      }
    });

    _sentScrollController.addListener(() {
      if (_sentScrollController.position.pixels >=
          _sentScrollController.position.maxScrollExtent - 200) {
        ref.read(reviewsControllerProvider.notifier).fetchSentReviews(isLoadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _receivedScrollController.dispose();
    _sentScrollController.dispose();
    _replyTextController.dispose();
    super.dispose();
  }

  void _showReplyDialog(BuildContext context, String reviewId) {
    _replyTextController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
        title: const Text(
          'الرد على التقييم',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اكتب ردك على هذا التقييم. يرجى العلم أنه لا يمكنك تعديل أو حذف الرد بعد إرساله.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.neutral600),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _replyTextController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'اكتب ردك هنا...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              style: const TextStyle(fontFamily: 'Cairo'),
              textAlign: TextAlign.right,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.neutral500)),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = _replyTextController.text.trim();
              if (text.isEmpty) return;

              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              try {
                await ref.read(reviewsControllerProvider.notifier).submitReply(reviewId, text);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال ردك بنجاح.', style: TextStyle(fontFamily: 'Cairo')),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('فشل إرسال الرد: $e', style: const TextStyle(fontFamily: 'Cairo')),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary600),
            child: const Text('إرسال', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text(
          'تقييماتي',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary600,
          labelColor: AppColors.primary600,
          unselectedLabelColor: AppColors.neutral500,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          tabs: const [
            Tab(text: 'تقييمات واردة'),
            Tab(text: 'تقييمات صادرة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReceivedTab(state),
          _buildSentTab(state),
        ],
      ),
    );
  }

  Widget _buildReceivedTab(ReviewsState state) {
    if (state.isLoadingReceived && state.receivedReviews.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary600));
    }

    if (state.receivedReviews.isEmpty) {
      return _buildEmptyState(
        icon: Icons.rate_review_outlined,
        title: 'لا توجد تقييمات واردة بعد',
        subtitle: 'التقييمات التي تتلقاها من المشترين الآخرين ستظهر هنا.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(reviewsControllerProvider.notifier).refreshAll(),
      color: AppColors.primary600,
      child: ListView.builder(
        controller: _receivedScrollController,
        padding: const EdgeInsets.all(AppSizes.lg),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.receivedReviews.length + (state.isLoadingReceived ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.receivedReviews.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary600)),
            );
          }

          final review = state.receivedReviews[index];
          final rating = review['rating'] as int? ?? 5;
          final comment = review['comment'] as String? ?? '';
          final reviewer = review['reviewer'] as Map<String, dynamic>?;
          final reviewerName = reviewer != null ? reviewer['full_name'] as String? ?? 'مستخدم وصلة' : 'مستخدم وصلة';
          final reviewerAvatar = reviewer != null ? reviewer['avatar_url'] as String? : null;

          String dateStr = '';
          if (review['created_at'] != null) {
            try {
              dateStr = DateFormat('yyyy/MM/dd').format(DateTime.parse(review['created_at']));
            } catch (_) {}
          }

          final responseList = review['review_responses'] as List?;
          final replyText = responseList != null && responseList.isNotEmpty
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                            ),
                            Text(
                              dateStr,
                              style: const TextStyle(color: AppColors.neutral500, fontSize: 11, fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: List.generate(5, (starIdx) {
                          return Icon(
                            Icons.star_rounded,
                            color: starIdx < rating ? AppColors.accent500 : AppColors.neutral300,
                            size: 18,
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    comment,
                    style: const TextStyle(fontSize: 14, height: 1.4, fontFamily: 'Cairo', color: AppColors.neutral800),
                  ),
                  
                  // Reply Section
                  if (replyText != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.reply_rounded, size: 16, color: AppColors.primary600),
                              SizedBox(width: 6),
                              Text(
                                'ردك:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary600, fontFamily: 'Cairo'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            replyText,
                            style: const TextStyle(fontSize: 13, color: AppColors.neutral700, fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _showReplyDialog(context, review['id']),
                        icon: const Icon(Icons.reply_rounded, size: 18),
                        label: const Text(
                          'رد على التقييم',
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary600,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSentTab(ReviewsState state) {
    if (state.isLoadingSent && state.sentReviews.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary600));
    }

    if (state.sentReviews.isEmpty) {
      return _buildEmptyState(
        icon: Icons.rate_review_outlined,
        title: 'لا توجد تقييمات صادرة بعد',
        subtitle: 'التقييمات التي ترسلها للبائعين والآخرين ستظهر هنا.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(reviewsControllerProvider.notifier).refreshAll(),
      color: AppColors.primary600,
      child: ListView.builder(
        controller: _sentScrollController,
        padding: const EdgeInsets.all(AppSizes.lg),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.sentReviews.length + (state.isLoadingSent ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.sentReviews.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary600)),
            );
          }

          final review = state.sentReviews[index];
          final rating = review['rating'] as int? ?? 5;
          final comment = review['comment'] as String? ?? '';
          final reviewed = review['reviewed'] as Map<String, dynamic>?;
          final reviewedName = reviewed != null ? reviewed['full_name'] as String? ?? 'مستخدم وصلة' : 'مستخدم وصلة';
          final reviewedAvatar = reviewed != null ? reviewed['avatar_url'] as String? : null;

          String dateStr = '';
          if (review['created_at'] != null) {
            try {
              dateStr = DateFormat('yyyy/MM/dd').format(DateTime.parse(review['created_at']));
            } catch (_) {}
          }

          final responseList = review['review_responses'] as List?;
          final replyText = responseList != null && responseList.isNotEmpty
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
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.neutral100,
                        backgroundImage: reviewedAvatar != null
                            ? CachedNetworkImageProvider(reviewedAvatar)
                            : const AssetImage(AppAssets.avatar) as ImageProvider,
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reviewedName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                            ),
                            Text(
                              dateStr,
                              style: const TextStyle(color: AppColors.neutral500, fontSize: 11, fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: List.generate(5, (starIdx) {
                          return Icon(
                            Icons.star_rounded,
                            color: starIdx < rating ? AppColors.accent500 : AppColors.neutral300,
                            size: 18,
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    comment,
                    style: const TextStyle(fontSize: 14, height: 1.4, fontFamily: 'Cairo', color: AppColors.neutral800),
                  ),
                  
                  // Reply Section from the reviewed user
                  if (replyText != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.reply_rounded, size: 16, color: AppColors.neutral500),
                              SizedBox(width: 6),
                              Text(
                                'الرد المستلم:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.neutral700, fontFamily: 'Cairo'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            replyText,
                            style: const TextStyle(fontSize: 13, color: AppColors.neutral700, fontFamily: 'Cairo'),
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
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.neutral300),
            const SizedBox(height: AppSizes.lg),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.neutral800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: AppColors.neutral500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
