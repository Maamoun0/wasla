import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repositories/saved_repository.dart';

/// The last list of saved ads, kept on the device per user so the Saved tab
/// works offline (NFR-3.2). Photos are cached separately by
/// CachedNetworkImage. Cleared on sign-out.
class SavedAdsCache {
  static const _prefix = 'saved_ads_cache:';

  static Future<void> write(String userId, List<Map<String, dynamic>> items, {DateTime? at}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$userId',
        jsonEncode({'saved_at': (at ?? DateTime.now()).toIso8601String(), 'items': items}));
  }

  static Future<({List<Map<String, dynamic>> items, DateTime savedAt})?> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$userId');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (
        items: (map['items'] as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList(),
        savedAt: DateTime.parse(map['saved_at'] as String),
      );
    } catch (_) {
      return null; // Corrupt or from an older format: ignore.
    }
  }

  /// Every user's copy (sign-out: nothing personal stays on the device).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await prefs.remove(k);
    }
  }
}

class SavedAdsResult {
  const SavedAdsResult(this.items, {this.cachedAt});
  final List<Map<String, dynamic>> items;

  /// Set when the list comes from the device because the server was unreachable.
  final DateTime? cachedAt;
  bool get fromCache => cachedAt != null;
}

/// Loads the user's saved ads from the server. Overridable in tests.
final savedAdsFetcherProvider = Provider<Future<List<Map<String, dynamic>>> Function(String userId)>((ref) {
  return (userId) async {
    return ref.read(savedRepositoryProvider).favoritesWithAds(userId);
  };
});

/// Server first; the device copy when offline; an error only if neither.
final savedAdsProvider = FutureProvider.autoDispose.family<SavedAdsResult, String>((ref, userId) async {
  try {
    final items = await ref.read(savedAdsFetcherProvider)(userId);
    await SavedAdsCache.write(userId, items);
    return SavedAdsResult(items);
  } catch (_) {
    final cached = await SavedAdsCache.read(userId);
    if (cached == null) rethrow;
    return SavedAdsResult(cached.items, cachedAt: cached.savedAt);
  }
});
