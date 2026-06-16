import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/providers/ads_provider.dart';
import '../../../shared/widgets/wasla_logo.dart' show EmptyState;
import '../../../features/auth/providers/auth_provider.dart';

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return _LoginPrompt();

    final favs = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('المحفوظة'),
        backgroundColor: AppColors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: favs.maybeWhen(data: (d) => 'المفضلة (${d.length})', orElse: () => 'المفضلة')),
            const Tab(text: 'تنبيهاتي'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FavoritesTab(userId: uid),
          _WatchlistTab(userId: uid),
        ],
      ),
    );
  }
}

// ── Favorites Tab ─────────────────────────────────────────────────
class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: client.from('favorites').select('''
        id, notes, created_at,
        ads(id, title, price, price_type, status, city_id,
          ad_media(url, is_primary),
          cities(name_ar))
      ''').eq('user_id', userId).order('created_at', ascending: false).then(
        (r) => (r as List).cast<Map<String, dynamic>>()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final favs = snapshot.data ?? [];
        if (favs.isEmpty) {
          return EmptyState(
            title: 'لا توجد إعلانات محفوظة',
            subtitle: 'اضغط على ♡ في أي إعلان لحفظه هنا',
            action: TextButton(
              onPressed: () => context.go(AppRoutes.explore),
              child: const Text('تصفح الإعلانات'),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: favs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _FavoriteCard(
            fav: favs[i],
            onRemove: () async {
              await client.from('favorites').delete().eq('id', favs[i]['id']);
              ref.invalidate(favoritesProvider);
            },
          ),
        );
      },
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.fav, required this.onRemove});
  final Map<String, dynamic> fav;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ad    = (fav['ads'] as Map?) ?? {};
    final media = (ad['ad_media'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final img   = media.firstWhere((m) => m['is_primary'] == true, orElse: () => media.isNotEmpty ? media[0] : {});
    final notes = fav['notes'] as String?;

    return GestureDetector(
      onTap: () => context.push('/ad/${ad['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
              child: img['url'] != null
                  ? CachedNetworkImage(
                      imageUrl: img['url'] as String,
                      width: 100, height: 100, fit: BoxFit.cover,
                    )
                  : Container(
                      width: 100, height: 100,
                      color: AppColors.neutral100,
                      child: const Icon(Icons.image_outlined, color: AppColors.neutral300, size: 36),
                    ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad['title'] as String? ?? '',
                      style: Theme.of(context).textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    if (notes != null && notes.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(notes, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    Row(children: [
                      const Icon(Icons.location_on_rounded, size: 12, color: AppColors.neutral400),
                      Text((ad['cities'] as Map?)?['name_ar'] as String? ?? '',
                        style: Theme.of(context).textTheme.labelSmall),
                    ]),
                  ],
                ),
              ),
            ),
            // Remove
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.neutral400, size: 20),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Watchlist Tab ──────────────────────────────────────────────────
class _WatchlistTab extends ConsumerWidget {
  const _WatchlistTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: client.from('saved_searches').select().eq('user_id', userId)
          .order('created_at', ascending: false)
          .then((r) => (r as List).cast<Map<String, dynamic>>()),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return EmptyState(
            title: 'لا توجد تنبيهات',
            subtitle: 'احفظ بحثاً لتصلك إشعارات بالإعلانات الجديدة',
            action: TextButton(
              onPressed: () => context.go(AppRoutes.explore),
              child: const Text('ابدأ البحث'),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _WatchlistCard(
            item: list[i],
            onToggle: () async {
              await client.from('saved_searches').update({
                'is_active': !(list[i]['is_active'] as bool? ?? true),
              }).eq('id', list[i]['id']);
            },
            onDelete: () async {
              await client.from('saved_searches').delete().eq('id', list[i]['id']);
            },
          ),
        );
      },
    );
  }
}

class _WatchlistCard extends StatefulWidget {
  const _WatchlistCard({required this.item, required this.onToggle, required this.onDelete});
  final Map<String, dynamic> item;
  final VoidCallback onToggle, onDelete;

  @override
  State<_WatchlistCard> createState() => _WatchlistCardState();
}

class _WatchlistCardState extends State<_WatchlistCard> {
  late bool _active;

  @override
  void initState() {
    super.initState();
    _active = widget.item['is_active'] as bool? ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name'] as String? ?? 'بحث محفوظ';
    final kw   = widget.item['keywords'] as String?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _active ? AppColors.primary200 : AppColors.neutral200),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _active ? AppColors.primary50 : AppColors.neutral100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.notifications_active_outlined,
              color: _active ? AppColors.primary600 : AppColors.neutral400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                if (kw != null && kw.isNotEmpty)
                  Text(kw, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Switch(
            value: _active,
            activeColor: AppColors.primary600,
            onChanged: (v) {
              setState(() => _active = v);
              widget.onToggle();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Login Prompt ──────────────────────────────────────────────────
class _LoginPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(title: const Text('المحفوظة')),
      body: EmptyState(
        title: 'سجّل دخولك أولاً',
        subtitle: 'لحفظ الإعلانات وإنشاء تنبيهات البحث',
        action: ElevatedButton(
          onPressed: () => context.push(AppRoutes.auth),
          child: const Text('تسجيل الدخول'),
        ),
      ),
    );
  }
}
