import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/providers/ads_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../../shared/widgets/wasla_logo.dart';
import '../../../core/location/location_service.dart';
import '../../../shared/providers/app_settings_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Radius of the home "near me" feed.
const nearMeRadiusKm = 50.0;

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(homeAdsNotifierProvider.notifier).load());
    _scrollController.addListener(_onScroll);
  }

  /// FR-2.1: nearest ads within [nearMeRadiusKm]; asks for location only now.
  Future<void> _showNearMe() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(locationReaderProvider)();
    final here = result.location;
    if (here == null) {
      messenger.showSnackBar(SnackBar(content: Text(result.message ?? '')));
      return;
    }
    ref.read(homeAdsNotifierProvider.notifier).applyFilter(
          AdsFilter(nearLat: here.lat, nearLng: here.lng, radiusKm: nearMeRadiusKm),
        );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(homeAdsNotifierProvider.notifier).load();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adsState   = ref.watch(homeAdsNotifierProvider);
    final featured   = ref.watch(featuredAdsProvider);
    final categories = ref.watch(categoriesProvider);
    final unread     = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── App Bar ─────────────────────────────────────────
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.white,
            elevation: 0,
            title: const WaslaLogoFull(size: 32),
            actions: [
              Stack(
                children: [
                  IconButton(
                    onPressed: () => context.push(AppRoutes.notifications),
                    icon: const Icon(Icons.notifications_outlined, color: AppColors.neutral700),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Search Bar ──────────────────────────────────────
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => context.go(AppRoutes.explore),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.neutral200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.neutral400),
                      const SizedBox(width: 10),
                      Text(
                        'ابحث عن خدمة، إعلان...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.neutral400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Categories Grid ──────────────────────────────────
          SliverToBoxAdapter(
            child: categories.when(
              data: (cats) => _CategoriesSection(categories: cats),
              loading: () => const SizedBox(height: 100),
              error: (_, __) => const SizedBox(),
            ),
          ),

          // ── Featured Ads ─────────────────────────────────────
          SliverToBoxAdapter(
            child: featured.when(
              data: (ads) => ads.isEmpty ? const SizedBox() : _FeaturedSection(ads: ads),
              loading: () => const SizedBox(height: 180),
              error: (_, __) => const SizedBox(),
            ),
          ),

          if (ref.watch(appSettingsProvider).valueOrNull?.maintenance ?? false)
            const SliverToBoxAdapter(child: MaintenanceBanner()),

          // ── Recent / Near-me Ads Header ──────────────────────
          SliverToBoxAdapter(
            child: SectionHeader(
              title: adsState.filter.isNearMe ? 'الأقرب ليك' : 'أحدث الإعلانات',
              action: () => context.go(AppRoutes.explore),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('الأحدث'),
                    selected: !adsState.filter.isNearMe,
                    onSelected: (_) => ref.read(homeAdsNotifierProvider.notifier).applyFilter(const AdsFilter()),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.near_me_outlined, size: 16),
                    label: const Text('الأقرب لي'),
                    selected: adsState.filter.isNearMe,
                    onSelected: (_) => _showNearMe(),
                  ),
                ],
              ),
            ),
          ),

          // ── Ads Grid ─────────────────────────────────────────
          if (adsState.isLoading && adsState.ads.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const AdCardShimmer(),
                  childCount: 6,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i == adsState.ads.length) {
                      return adsState.hasMore
                          ? const Center(child: CircularProgressIndicator())
                          : const SizedBox();
                    }
                    return AdCard(ad: adsState.ads[i]);
                  },
                  childCount: adsState.ads.length + (adsState.hasMore ? 1 : 0),
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── Categories Section ────────────────────────────────────────────
class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({required this.categories});
  final List<Map<String, dynamic>> categories;

  static const _catIcons = {
    'services':    '🔧',
    'jobs':        '💼',
    'real-estate': '🏠',
    'vehicles':    '🚗',
    'goods':       '📦',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'الأقسام'),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final cat  = categories[i];
              final slug = cat['slug'] as String? ?? '';
              final icon = _catIcons[slug] ?? cat['icon'] ?? '📦';

              return GestureDetector(
                onTap: () => ctx.push(exploreLocation(AdsFilter(categoryId: '${cat['id']}'))),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.neutral200),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neutral900.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(child: Text(icon, style: const TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat['name_ar'] as String? ?? '',
                      style: Theme.of(ctx).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Featured Ads Horizontal List ──────────────────────────────────
class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection({required this.ads});
  final List<Map<String, dynamic>> ads;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '⭐ إعلانات مميزة',
          action: () => context.push(exploreLocation(const AdsFilter(featuredOnly: true))),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ads.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) => SizedBox(width: 180, child: AdCard(ad: ads[i])),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Shown while the admin has maintenance mode on.
class MaintenanceBanner extends StatelessWidget {
  const MaintenanceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: const Row(
        children: [
          Icon(Icons.construction_rounded, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'التطبيق في وضع الصيانة: نشر الإعلانات والدفع والتوثيق متوقفين مؤقتاً. التصفح شغال عادي.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
