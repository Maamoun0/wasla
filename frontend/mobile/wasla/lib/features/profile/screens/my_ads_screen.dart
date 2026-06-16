import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/wasla_logo.dart' show EmptyState;
import '../../../features/auth/providers/auth_provider.dart';

class MyAdsScreen extends ConsumerStatefulWidget {
  const MyAdsScreen({super.key});

  @override
  ConsumerState<MyAdsScreen> createState() => _MyAdsScreenState();
}

class _MyAdsScreenState extends ConsumerState<MyAdsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  final _statuses = [
    ('active',   'نشطة',   AppColors.success),
    ('pending',  'معلّقة', AppColors.warning),
    ('expired',  'منتهية', AppColors.neutral500),
    ('rejected', 'مرفوضة',AppColors.error),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('إعلاناتي'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: _statuses.map((s) => Tab(
            child: Text(s.$2, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
          )).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: _statuses.map((s) => _AdsByStatus(status: s.$1, statusColor: s.$3)).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.postCategory),
        backgroundColor: AppColors.primary600,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('إعلان جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}

class _AdsByStatus extends ConsumerWidget {
  const _AdsByStatus({required this.status, required this.statusColor});
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid    = ref.watch(currentUserIdProvider);
    final client = ref.watch(supabaseClientProvider);
    if (uid == null) return const SizedBox();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: client.from('ads').select('''
        id, title, price, price_type, views_count, contacts_count, favorites_count,
        created_at, expires_at, rejection_reason, is_featured,
        ad_media(url, is_primary),
        cities(name_ar)
      ''').eq('user_id', uid).eq('status', status)
          .order('created_at', ascending: false)
          .then((r) => (r as List).cast<Map<String, dynamic>>()),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final ads = snap.data ?? [];
        if (ads.isEmpty) {
          return EmptyState(
            title: 'لا توجد إعلانات',
            subtitle: status == 'active' ? 'انشر إعلانك الأول الآن!' : 'لا يوجد في هذه الحالة',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => (ctx as Element).markNeedsBuild(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _MyAdCard(ad: ads[i], status: status, statusColor: statusColor),
          ),
        );
      },
    );
  }
}

class _MyAdCard extends ConsumerWidget {
  const _MyAdCard({required this.ad, required this.status, required this.statusColor});
  final Map<String, dynamic> ad;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media  = (ad['ad_media'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final img    = media.firstWhere((m) => m['is_primary'] == true, orElse: () => media.isNotEmpty ? media.first : {});
    final imgUrl = img['url'] as String?;
    final views  = ad['views_count'] as int? ?? 0;
    final ctcts  = ad['contacts_count'] as int? ?? 0;
    final favs   = ad['favorites_count'] as int? ?? 0;
    final isFeat = ad['is_featured'] == true;
    final reason = ad['rejection_reason'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isFeat ? AppColors.accent500 : AppColors.neutral200,
          width: isFeat ? 1.5 : 1),
      ),
      child: Column(
        children: [
          // ── Top Row ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imgUrl != null
                      ? CachedNetworkImage(imageUrl: imgUrl, width: 72, height: 72, fit: BoxFit.cover)
                      : Container(width: 72, height: 72, color: AppColors.neutral100,
                          child: const Icon(Icons.image_outlined, color: AppColors.neutral300)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(ad['title'] as String? ?? '',
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        if (isFeat)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.accent50, borderRadius: BorderRadius.circular(6)),
                            child: const Text('⭐ مميز', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent600)),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_statusLabel(status),
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Rejection reason
          if (reason != null && status == 'rejected')
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text('سبب الرفض: $reason',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.error))),
              ]),
            ),

          const Divider(height: 1),

          // ── Stats ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _StatChip(icon: Icons.visibility_outlined,    value: views,  label: 'مشاهدة'),
                const SizedBox(width: 12),
                _StatChip(icon: Icons.phone_outlined,         value: ctcts,  label: 'تواصل'),
                const SizedBox(width: 12),
                _StatChip(icon: Icons.favorite_border_rounded, value: favs,  label: 'حفظ'),
                const Spacer(),
                // Actions
                if (status == 'active') ...[
                  _ActionIcon(icon: Icons.flash_on_rounded, color: AppColors.accent500,
                    onTap: () => context.push('/profile/boost/${ad['id']}')),
                  _ActionIcon(icon: Icons.bar_chart_rounded, color: AppColors.primary600,
                    onTap: () => context.push('/profile/performance/${ad['id']}')),
                ],
                _ActionIcon(icon: Icons.open_in_new_rounded, color: AppColors.neutral500,
                  onTap: () => context.push('/ad/${ad['id']}')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
    'active'   => '● نشط',
    'pending'  => '⏳ قيد المراجعة',
    'expired'  => '⏰ منتهي',
    'rejected' => '✗ مرفوض',
    'paused'   => '⏸ موقوف',
    'sold'     => '✓ تم البيع',
    _          => s,
  };
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value, required this.label});
  final IconData icon; final int value; final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.neutral400),
        const SizedBox(width: 3),
        Text('$value', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.neutral700)),
      ]),
      Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.neutral400)),
    ],
  );
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.color, required this.onTap});
  final IconData icon; final Color color; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Icon(icon, size: 22, color: color),
    ),
  );
}
