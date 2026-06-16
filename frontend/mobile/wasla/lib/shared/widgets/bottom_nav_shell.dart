import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';

class BottomNavShell extends StatelessWidget {
  const BottomNavShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    _NavTab(icon: Icons.home_rounded,       label: AppStrings.home,    route: AppRoutes.home),
    _NavTab(icon: Icons.search_rounded,     label: AppStrings.explore, route: AppRoutes.explore),
    _NavTab(icon: Icons.add,                label: AppStrings.post,    route: AppRoutes.postCategory, isCenter: true),
    _NavTab(icon: Icons.favorite_rounded,   label: AppStrings.saved,   route: AppRoutes.saved),
    _NavTab(icon: Icons.person_rounded,     label: AppStrings.profile, route: AppRoutes.profile),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.neutral900.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: AppSizes.bottomNavHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isSelected = i == current;

                if (tab.isCenter) {
                  return _CenterAddButton(
                    onTap: () => context.go(tab.route),
                  );
                }

                return _NavItem(
                  tab: tab,
                  isSelected: isSelected,
                  onTap: () => context.go(tab.route),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav Item ──────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });
  final _NavTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppDurations.fast,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary50 : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                tab.icon,
                size: 22,
                color: isSelected ? AppColors.primary600 : AppColors.neutral400,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary600 : AppColors.neutral400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Center Add Button ─────────────────────────────────────────────
class _CenterAddButton extends StatelessWidget {
  const _CenterAddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary600.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
          ),
          Text(
            AppStrings.post,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.route,
    this.isCenter = false,
  });
  final IconData icon;
  final String label;
  final String route;
  final bool isCenter;
}
