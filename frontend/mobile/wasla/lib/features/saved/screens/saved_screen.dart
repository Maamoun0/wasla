import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/supabase/push_notification_service.dart';
import '../../../shared/providers/ads_provider.dart';
import '../../../shared/widgets/wasla_logo.dart' show EmptyState;
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/saved_searches_provider.dart';
import '../providers/saved_ads_provider.dart';

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key, this.initialTab = 0});

  /// 0: favorites, 1: saved-search alerts (/saved?tab=alerts).
  final int initialTab;

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
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
        title: Text('saved'.tr()),
        backgroundColor: AppColors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
                text: favs.maybeWhen(
                    data: (d) => '${'favorites'.tr()} (${d.length})',
                    orElse: () => 'favorites'.tr())),
            Tab(text: 'myAlerts'.tr()),
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

// ──────────────────────────────────────────────────────────────────────────
class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedAdsProvider(userId));
    if (saved.isLoading && !saved.hasValue) return const Center(child: CircularProgressIndicator());
    if (saved.hasError && !saved.hasValue) {
      return EmptyState(
        title: 'تعذّر تحميل المحفوظات',
        subtitle: 'تحقق من اتصالك وحاول مرة أخرى.',
        action: TextButton(onPressed: () => ref.invalidate(savedAdsProvider(userId)), child: const Text('إعادة المحاولة')),
      );
    }
    final result = saved.requireValue;
    return Column(
      children: [
        if (result.fromCache) _OfflineBanner(savedAt: result.cachedAt!, onRetry: () => ref.invalidate(savedAdsProvider(userId))),
        Expanded(child: _favoritesList(context, ref, result.items)),
      ],
    );
  }

  Widget _favoritesList(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> favs) {
    return Builder(
      builder: (context) {
        if (favs.isEmpty) {
          return EmptyState(
            title: 'noSavedAds'.tr(),
            subtitle: 'saveAdInstructions'.tr(),
            action: TextButton(
              onPressed: () => context.go(AppRoutes.explore),
              child: Text('browseAds'.tr()),
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
              await ref.read(supabaseClientProvider).from('favorites').delete().eq('id', favs[i]['id']);
              ref.invalidate(favoritesProvider);
              ref.invalidate(savedAdsProvider(userId));
            },
          ),
        );
      },
    );
  }
}

/// Shown when the list comes from the device (no connection).
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.savedAt, required this.onRetry});
  final DateTime savedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = savedAt.toLocal();
    final when = '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Material(
      color: AppColors.neutral100,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.cloud_off_rounded),
        title: Text('إنت مش متصل. دي آخر نسخة محفوظة على الجهاز ($when).'),
        trailing: TextButton(onPressed: onRetry, child: const Text('تحديث')),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.fav, required this.onRemove});
  final Map<String, dynamic> fav;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ad = (fav['ads'] as Map?) ?? {};
    final media = (ad['ad_media'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final img = media.firstWhere((m) => m['is_primary'] == true,
        orElse: () => media.isNotEmpty ? media[0] : {});
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
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(14)),
              child: img['url'] != null
                  ? CachedNetworkImage(
                      imageUrl: img['url'] as String,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: AppColors.neutral100,
                      child: const Icon(Icons.image_outlined,
                          color: AppColors.neutral300, size: 36),
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
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    if (notes != null && notes.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(notes,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.primary600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    Row(children: [
                      const Icon(Icons.location_on_rounded,
                          size: 12, color: AppColors.neutral400),
                      Text((ad['cities'] as Map?)?['name_ar'] as String? ?? '',
                          style: Theme.of(context).textTheme.labelSmall),
                    ]),
                  ],
                ),
              ),
            ),
            // Remove
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.neutral400, size: 20),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
class _WatchlistTab extends ConsumerWidget {
  const _WatchlistTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    final searches = ref.watch(savedSearchesProvider);

    return searches.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => EmptyState(
        title: 'تعذّر تحميل عمليات البحث المحفوظة',
        subtitle: 'تحقق من اتصالك وحاول مرة أخرى.',
        action: TextButton(
            onPressed: () => ref.invalidate(savedSearchesProvider),
            child: const Text('إعادة المحاولة')),
      ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            title: 'noAlerts'.tr(),
            subtitle: 'saveSearchInstructions'.tr(),
            action: TextButton(
              onPressed: () => context.go(AppRoutes.explore),
              child: Text('startSearch'.tr()),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _WatchlistCard(
            key: ValueKey(list[i]['id']),
            item: list[i],
            onOpen: () {
              ref
                  .read(adsNotifierProvider.notifier)
                  .applyFilter(adsFilterFromSavedSearch(list[i]));
              context.go(AppRoutes.explore);
            },
            onToggle: (active) async {
              await client
                  .from('saved_searches')
                  .update({'is_active': active}).eq('id', list[i]['id']);
            },
            onDelete: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('حذف البحث المحفوظ؟'),
                  content: const Text('مش هتوصلك تنبيهات عن البحث ده تاني.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('إلغاء')),
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('حذف')),
                  ],
                ),
              );
              if (confirmed != true) return;
              await client
                  .from('saved_searches')
                  .delete()
                  .eq('id', list[i]['id']);
              ref.invalidate(savedSearchesProvider);
            },
          ),
        );
      },
    );
  }
}

class _WatchlistCard extends StatefulWidget {
  const _WatchlistCard(
      {super.key,
      required this.item,
      required this.onOpen,
      required this.onToggle,
      required this.onDelete});
  final Map<String, dynamic> item;
  final VoidCallback onOpen, onDelete;
  final Future<void> Function(bool active) onToggle;

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
    final name = widget.item['name'] as String? ?? 'savedSearch'.tr();
    final kw = widget.item['keywords'] as String?;

    return InkWell(
      onTap: widget.onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _active ? AppColors.primary200 : AppColors.neutral200),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
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
                    Text(kw,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Switch(
              value: _active,
              activeThumbColor: AppColors.primary600,
              onChanged: (v) async {
                if (v) {
                  // Request permission when enabling notifications (Piece 1.2)
                  final granted =
                      await PushNotificationService.requestPermission();
                  if (!granted) return;
                }
                setState(() => _active = v);
                await widget.onToggle(v);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 20),
              onPressed: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
class _LoginPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(title: Text('saved'.tr())),
      body: EmptyState(
        title: 'loginFirst'.tr(),
        subtitle: 'loginFirstDesc'.tr(),
        action: ElevatedButton(
          onPressed: () => context.push(authLocation(from: AppRoutes.saved)),
          child: Text('login'.tr()),
        ),
      ),
    );
  }
}
