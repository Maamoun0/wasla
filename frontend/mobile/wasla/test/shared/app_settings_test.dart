import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/features/home/screens/home_screen.dart';
import 'package:wasla/features/notifications/providers/notifications_provider.dart';
import 'package:wasla/data/repositories/ads_repository.dart';
import 'package:wasla/shared/providers/ads_provider.dart';
import 'package:wasla/shared/providers/app_settings_provider.dart';

/// A feed that never calls the server.
class _NoopFeed extends AdsNotifier {
  _NoopFeed() 
      : super(AdsRepository(SupabaseClient('http://localhost:1', 'k', authOptions: const AuthClientOptions(autoRefreshToken: false))));

  @override
  Future<void> load({AdsFilter? filter, bool refresh = false}) async {
    state = AdsState(filter: filter ?? state.filter, hasMore: false);
  }
}

void main() {
  group('AppSettings.fromRows', () {
    test('reads the switches as the admin panel saves them', () {
      final s = AppSettings.fromRows([
        {'key': 'maintenance_mode', 'value': true},
        {'key': 'enable_boost_feature', 'value': false},
        {'key': 'enable_kyc_verification', 'value': 'false'},
      ]);
      expect([s.maintenance, s.boostEnabled, s.kycEnabled], [true, false, false]);
    });

    test('missing or odd values keep today\'s behaviour', () {
      final s = AppSettings.fromRows([
        {'key': 'maintenance_mode', 'value': 42},
      ]);
      expect([s.maintenance, s.boostEnabled, s.kycEnabled], [false, true, true]);
    });
  });

  testWidgets('Home shows the maintenance banner only while maintenance is on', (tester) async {
    Future<void> pump(AppSettings settings) async {
      // A fresh scope per case: overrides are fixed for a scope's lifetime.
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          appSettingsProvider.overrideWith((ref) async => settings),
          homeAdsNotifierProvider.overrideWith((ref) => _NoopFeed()),
          categoriesProvider.overrideWith((ref) async => const []),
          featuredAdsProvider.overrideWith((ref) async => const []),
          unreadCountProvider.overrideWith((ref) async => 0),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ));
      await tester.pumpAndSettle();
    }

    await pump(const AppSettings(maintenance: true));
    expect(find.byType(MaintenanceBanner), findsOneWidget);
    await pump(const AppSettings());
    expect(find.byType(MaintenanceBanner), findsNothing);
  });
}
