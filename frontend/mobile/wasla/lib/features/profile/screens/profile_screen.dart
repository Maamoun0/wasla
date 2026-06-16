import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/wasla_logo.dart' show VerifiedBadge;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _GuestView(),
        data: (user) => user == null ? _GuestView() : _LoggedInView(user: user),
      ),
    );
  }
}

// ── Guest View ────────────────────────────────────────────────────
class _GuestView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline_rounded, size: 80, color: AppColors.neutral300),
              const SizedBox(height: 20),
              Text('سجّل دخولك', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('لإدارة إعلاناتك وتفضيلاتك',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.neutral500),
                textAlign: TextAlign.center),
              const SizedBox(height: 32),
              SizedBox(
                width: 220,
                child: ElevatedButton(
                  onPressed: () => context.push(AppRoutes.auth),
                  child: const Text('تسجيل الدخول'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logged In View ────────────────────────────────────────────────
class _LoggedInView extends ConsumerWidget {
  const _LoggedInView({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name       = user['full_name'] as String? ?? 'مستخدم';
    final avatar     = user['avatar_url'] as String?;
    final score      = (user['trust_score'] as num?)?.toDouble() ?? 0;
    final isVerified = user['is_id_verified'] == true;
    final userType   = user['user_type'] as String? ?? 'regular';

    return CustomScrollView(
      slivers: [
        // ── Header ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('حسابي', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white),
                      onPressed: () => context.push(AppRoutes.settings),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.primary50,
                          backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                          child: avatar == null ? const Icon(Icons.person_rounded, size: 40, color: AppColors.primary200) : null,
                        ),
                        Positioned(
                          bottom: 0, left: 0,
                          child: GestureDetector(
                            onTap: () {/* Edit profile */},
                            child: Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.accent500,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 4),
                          Row(children: [
                            if (isVerified) ...[const VerifiedBadge(), const SizedBox(width: 6)],
                            // Stars
                            ...List.generate(5, (i) => Icon(
                              i < score.round() ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 14, color: AppColors.accent300,
                            )),
                            const SizedBox(width: 4),
                            Text(score.toStringAsFixed(1), style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 12)),
                          ]),
                          if (userType == 'business')
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.accent500, borderRadius: BorderRadius.circular(6)),
                              child: const Text('أعمال', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Verification Banner ───────────────────────────
        if (!isVerified)
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.verification),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent500.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.verified_user_outlined, color: AppColors.accent600),
                  const SizedBox(width: 10),
                  Expanded(child: Text('وثّق حسابك بالرقم القومي لزيادة ثقة العملاء',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.accent800))),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.accent600),
                ]),
              ),
            ),
          ),

        // ── Menu Items ────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                _MenuSection(title: 'إعلاناتي', items: [
                  _MenuItem(icon: Icons.campaign_outlined,    label: 'إعلاناتي',           route: AppRoutes.myAds),
                  _MenuItem(icon: Icons.favorite_outline,     label: 'المفضلة',             route: AppRoutes.saved),
                  _MenuItem(icon: Icons.notifications_none,   label: 'التنبيهات المحفوظة',  route: AppRoutes.saved),
                ]),
                const SizedBox(height: 12),
                _MenuSection(title: 'الحساب', items: [
                  _MenuItem(icon: Icons.workspace_premium_outlined, label: 'اشتراكي', route: AppRoutes.subscription),
                  _MenuItem(icon: Icons.verified_outlined,          label: 'التحقق من الهوية', route: AppRoutes.verification),
                  _MenuItem(icon: Icons.star_outline_rounded,       label: 'تقييماتي', route: AppRoutes.myReviews),
                ]),
                const SizedBox(height: 12),
                _MenuSection(title: 'الإعدادات', items: [
                  _MenuItem(icon: Icons.settings_outlined, label: 'الإعدادات', route: AppRoutes.settings),
                  _MenuItem(
                    icon: Icons.logout_rounded,
                    label: 'تسجيل الخروج',
                    color: AppColors.error,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Cairo')),
                          content: const Text('هل تريد تسجيل الخروج؟', style: TextStyle(fontFamily: 'Cairo')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                            TextButton(onPressed: () => Navigator.pop(context, true),
                              child: const Text('خروج', style: TextStyle(color: AppColors.error))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(authNotifierProvider.notifier).signOut();
                        if (context.mounted) context.go(AppRoutes.auth);
                      }
                    },
                  ),
                ]),
                const SizedBox(height: 32),

                // App version
                Text('وصلة v1.0.0', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral300)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.items});
  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.neutral400, letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, this.route, this.onTap, this.color});
  final IconData icon;
  final String label;
  final String? route;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.neutral700;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 14, color: c)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.neutral300),
      onTap: onTap ?? (route != null ? () => context.push(route!) : null),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
