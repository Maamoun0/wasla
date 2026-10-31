import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/ad_performance_provider.dart';

class AdPerformanceScreen extends ConsumerWidget {
  const AdPerformanceScreen({super.key, required this.adId});
  final String adId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perf = ref.watch(adPerformanceProvider(adId));
    return Scaffold(
      appBar: AppBar(title: const Text('أداء الإعلان')),
      body: perf.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(adPerformanceProvider(adId)),
            child: const Text('تعذّر تحميل الأرقام. إعادة المحاولة'),
          ),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(adPerformanceProvider(adId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(p.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: [
                  _Stat(icon: Icons.visibility_outlined, label: 'مشاهدات', value: '${p.views}'),
                  _Stat(icon: Icons.phone_outlined, label: 'اتصالات', value: '${p.calls}'),
                  _Stat(icon: Icons.chat_outlined, label: 'واتساب', value: '${p.whatsapp}'),
                  _Stat(icon: Icons.favorite_border_rounded, label: 'حفظ في المفضلة', value: '${p.favorites}'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                p.contactRate == null
                    ? 'لسه مفيش مشاهدات.'
                    : 'من كل 100 مشاهدة، ${p.contactRate!.toStringAsFixed(1)} تواصلوا معاك.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text('آخر 30 يوم', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _DailyBars(daily: p.daily),
              const SizedBox(height: 8),
              const Row(
                children: [
                  _Legend(color: AppColors.primary600, label: 'مشاهدات'),
                  SizedBox(width: 16),
                  _Legend(color: AppColors.accent500, label: 'تواصل'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One pair of bars per day, scaled to the busiest day.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.daily});
  final List<DailyStat> daily;

  @override
  Widget build(BuildContext context) {
    final peak = daily.fold<int>(1, (m, d) => [m, d.views, d.contacts].reduce((a, b) => a > b ? a : b));
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in daily)
            Expanded(
              child: Tooltip(
                message: '${d.day.day}/${d.day.month}: ${d.views} مشاهدة، ${d.contacts} تواصل',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: Container(height: 120 * d.views / peak, color: AppColors.primary600)),
                    Expanded(child: Container(height: 120 * d.contacts / peak, color: AppColors.accent500)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}
