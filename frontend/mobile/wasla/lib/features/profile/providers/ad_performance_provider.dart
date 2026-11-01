import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/ads_repository.dart';

class DailyStat {
  const DailyStat(this.day, this.views, this.contacts);
  final DateTime day;
  final int views;
  final int contacts;
}

/// The owner's numbers for one ad (ad_performance).
class AdPerformance {
  const AdPerformance({
    required this.title,
    required this.views,
    required this.favorites,
    required this.calls,
    required this.whatsapp,
    required this.daily,
    this.expiresAt,
  });

  final String title;
  final int views;
  final int favorites;
  final int calls;
  final int whatsapp;
  final List<DailyStat> daily;
  final DateTime? expiresAt;

  int get contacts => calls + whatsapp;

  /// Contacts per 100 views, or null before any view.
  double? get contactRate => views == 0 ? null : contacts * 100 / views;

  factory AdPerformance.fromJson(Map<String, dynamic> j) {
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return AdPerformance(
      title: j['title'] as String? ?? '',
      views: n(j['views']),
      favorites: n(j['favorites']),
      calls: n(j['calls']),
      whatsapp: n(j['whatsapp']),
      expiresAt: DateTime.tryParse(j['expires_at'] as String? ?? ''),
      daily: [
        for (final d in (j['daily'] as List? ?? const []).cast<Map>())
          DailyStat(DateTime.parse(d['day'] as String), n(d['views']), n(d['contacts'])),
      ],
    );
  }
}

final adPerformanceProvider = FutureProvider.autoDispose.family<AdPerformance, String>((ref, adId) async {
  return AdPerformance.fromJson(await ref.watch(adsRepositoryProvider).adPerformance(adId));
});

/// Counts a view of an ad page (record_ad_view decides what counts). Never
/// blocks or fails the page.
final adViewRecorderProvider = Provider<Future<void> Function(String adId)>((ref) => (adId) async {
      try {
        await ref.read(adsRepositoryProvider).recordAdView(adId);
      } catch (_) {}
    });
