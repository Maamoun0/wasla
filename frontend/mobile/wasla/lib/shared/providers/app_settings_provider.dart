import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/config_repository.dart';

/// The admin switches the app reflects. The server enforces each of them;
/// the app only hides what would be refused and explains maintenance.
class AppSettings {
  const AppSettings({this.maintenance = false, this.boostEnabled = true, this.kycEnabled = true});

  final bool maintenance;
  final bool boostEnabled;
  final bool kycEnabled;

  /// From app_configs rows ({key, value}); missing or unreadable keys keep today's behaviour.
  factory AppSettings.fromRows(List<Map<String, dynamic>> rows) {
    bool? flag(String key) {
      final v = rows.where((r) => r['key'] == key).firstOrNull?['value'];
      if (v is bool) return v;
      if (v is String) return v == 'true' ? true : (v == 'false' ? false : null);
      return null;
    }

    return AppSettings(
      maintenance: flag('maintenance_mode') ?? false,
      boostEnabled: flag('enable_boost_feature') ?? true,
      kycEnabled: flag('enable_kyc_verification') ?? true,
    );
  }
}

final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  try {
    final rows = await ref
        .watch(configRepositoryProvider)
        .configs(['maintenance_mode', 'enable_boost_feature', 'enable_kyc_verification']);
    return AppSettings.fromRows(rows);
  } catch (_) {
    return const AppSettings();
  }
});
