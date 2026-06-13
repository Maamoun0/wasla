import 'package:flutter/material.dart';
import '../../../core/theme/wasla_theme.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المحفوظات'),
          bottom: const TabBar(
            indicatorColor: WaslaTheme.secondaryGold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'الإعلانات المفضلة'),
              Tab(text: 'البحوث المحفوظة'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FavoritesTab(),
            WatchlistTab(),
          ],
        ),
      ),
    );
  }
}

class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 60, color: WaslaTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            'لا توجد إعلانات محفوظة حالياً',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: WaslaTheme.textMuted,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'احفظ الإعلانات التي تهمك للوصول إليها لاحقاً',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WaslaTheme.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class WatchlistTab extends StatelessWidget {
  const WatchlistTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_none, size: 60, color: WaslaTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            'لا توجد تنبيهات محفوظة',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: WaslaTheme.textMuted,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'احفظ كلمات البحث لتصلك إشعارات بالإعلانات الجديدة',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WaslaTheme.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}
