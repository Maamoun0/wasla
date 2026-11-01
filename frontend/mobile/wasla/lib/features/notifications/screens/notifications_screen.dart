import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/wasla_logo.dart' show EmptyState;
import '../../auth/providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../../../data/repositories/notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markRead(WidgetRef ref, {List<String>? ids}) async {
    await ref.read(notificationsRepositoryProvider).markRead(ids);
    ref.invalidate(unreadCountProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(currentUserIdProvider) != null;
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _markRead(ref),
              child: const Text('تحديد الكل كمقروء'),
            ),
        ],
      ),
      body: !isLoggedIn
          ? EmptyState(
              title: 'سجّل الدخول لعرض إشعاراتك',
              subtitle: 'هنا هتلاقي قبول إعلاناتك وتنبيهات البحث المحفوظ.',
              action: TextButton(onPressed: () => context.push(authLocation(from: AppRoutes.notifications)), child: const Text('تسجيل الدخول')),
            )
          : notifications.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => EmptyState(
                title: 'تعذّر تحميل الإشعارات',
                subtitle: 'تحقق من اتصالك وحاول مرة أخرى.',
                action: TextButton(
                  onPressed: () => ref.invalidate(notificationsProvider),
                  child: const Text('إعادة المحاولة'),
                ),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      title: 'مفيش إشعارات لسه',
                      subtitle: 'هيوصلك هنا قبول إعلاناتك وأي إعلان جديد يطابق بحثك المحفوظ.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(notificationsProvider);
                        ref.invalidate(unreadCountProvider);
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => _NotificationTile(
                          item: list[i],
                          onTap: () async {
                            final n = list[i];
                            if (n['is_read'] != true) await _markRead(ref, ids: [n['id'] as String]);
                            final route = notificationRoute((n['data'] as Map?)?.cast<String, dynamic>());
                            if (route != null && context.mounted) context.push(route);
                          },
                        ),
                      ),
                    ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  static IconData _icon(String? type) => switch (type) {
        'ad_approved' => Icons.check_circle_outline_rounded,
        'ad_rejected' => Icons.cancel_outlined,
        'saved_search_match' => Icons.notifications_active_outlined,
        'new_review' => Icons.star_outline_rounded,
        'boost_expiring' => Icons.trending_up_rounded,
        _ => Icons.notifications_none_rounded,
      };

  static Color _color(String? type) => switch (type) {
        'ad_approved' => AppColors.success,
        'ad_rejected' => AppColors.error,
        _ => AppColors.primary600,
      };

  @override
  Widget build(BuildContext context) {
    final unread = item['is_read'] != true;
    final type = item['type'] as String?;
    final created = DateTime.tryParse(item['created_at'] as String? ?? '');

    return Material(
      color: unread ? AppColors.primary50 : AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _color(type).withValues(alpha: 0.12),
                child: Icon(_icon(type), color: _color(type), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] as String? ?? '',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(item['body'] as String? ?? '', style: Theme.of(context).textTheme.bodySmall),
                    if (created != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        relativeTimeAr(created),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.neutral500),
                      ),
                    ],
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(color: AppColors.primary600, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
