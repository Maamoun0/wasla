import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/data/repositories/auth_repository.dart';
import 'package:wasla/features/auth/providers/auth_provider.dart';
import 'package:wasla/features/auth/screens/otp_screen.dart';
import 'package:wasla/features/legal/legal_provider.dart';
import 'package:wasla/features/notifications/providers/notifications_provider.dart';
import 'package:wasla/features/notifications/screens/notifications_screen.dart';
import 'package:wasla/features/profile/screens/notification_settings_screen.dart';
import 'package:wasla/features/profile/screens/settings_screen.dart';
import 'package:wasla/shared/widgets/primary_button.dart';

import '../helpers/fake_backend.dart';

class _FakeAuth extends AuthNotifier {
  _FakeAuth()
      : super(AuthRepository(SupabaseClient('http://localhost:1', 'k', authOptions: const AuthClientOptions(autoRefreshToken: false))));
  static const acceptCode = '123456';
  final verified = <String>[];
  final sent = <String>[];
  int signOuts = 0;

  @override
  Future<void> verifyOtp({required String phone, required String token}) async {
    if (token != acceptCode) throw const AuthException('invalid');
    verified.add('$phone:$token');
  }

  @override
  Future<void> sendOtp(String phone) async => sent.add(phone);

  @override
  Future<void> signOut() async => signOuts++;
}

/// The code field's cursor blinks forever, so pump a fixed time instead of settling.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _typeCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField).first, code);
  await _settle(tester);
}

void main() {
  group('OTP', () {
    Future<(FakeBackend, NavProbe, _FakeAuth, List<int>)> pump(WidgetTester tester, {String? fullName}) async {
      final auth = _FakeAuth();
      final accepted = <int>[];
      final backend = FakeBackend({
        '/rest/v1/rpc/get_my_profile': (_) => {'id': 'u1', 'full_name': fullName},
      });
      final nav = NavProbe();
      await pumpScreen(tester, const OtpScreen(phone: '+201012345678', initialWaitSeconds: 0, returnTo: '/ad/a1'),
          backend: backend,
          nav: nav,
          settle: false,
          overrides: [
            authNotifierProvider.overrideWith((ref) => auth),
            acceptCurrentLegalProvider.overrideWith((ref) => () async {
                  accepted.add(1);
                  return true;
                }),
          ]);
      return (backend, nav, auth, accepted);
    }

    testWidgets('a correct code records consent and returns to the page that asked', (tester) async {
      final (_, nav, auth, accepted) = await pump(tester, fullName: 'سارة');
      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).isDisabled, isTrue);

      // The sixth digit submits by itself.
      await _typeCode(tester, '123456');

      expect(auth.verified, ['+201012345678:123456']);
      expect(accepted, [1]);
      expect(nav.location, '/ad/a1');
    });

    testWidgets('a new user without a name goes to profile setup, keeping where to return', (tester) async {
      final (_, nav, _, _) = await pump(tester);
      // The sixth digit submits by itself.
      await _typeCode(tester, '123456');
      expect(nav.location, '/auth/setup?from=%2Fad%2Fa1');
    });

    testWidgets('a wrong code says so and clears the field', (tester) async {
      final (_, nav, auth, _) = await pump(tester, fullName: 'سارة');
      await _typeCode(tester, '000000');
      expect(find.text('رمز التحقق غير صحيح. حاول مرة أخرى.'), findsOneWidget);
      expect(auth.verified, isEmpty);
      expect(nav.location, isNull);
    });

    testWidgets('resend asks for a new code and restarts the countdown', (tester) async {
      final (_, _, auth, _) = await pump(tester, fullName: 'سارة');
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();
      expect(auth.sent, ['+201012345678']);
      expect(find.textContaining('إعادة الإرسال خلال'), findsOneWidget);
      // Let the countdown run out.
      await tester.pump(const Duration(seconds: 61));
    });
  });

  group('settings', () {
    testWidgets('deleting the account sends the reason, then signs out', (tester) async {
      final auth = _FakeAuth();
      final backend = FakeBackend({'/rest/v1/rpc/request_account_deletion': (_) => {'success': true}});
      final nav = NavProbe();
      await pumpScreen(tester, const SettingsScreen(), backend: backend, nav: nav, localized: true,
          overrides: [authNotifierProvider.overrideWith((ref) => auth)]);

      await tester.tap(find.text('حذف الحساب'));
      await tester.pumpAndSettle();
      expect(find.text('تأكيد حذف الحساب'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'مش محتاج التطبيق');
      await tester.tap(find.text('تأكيد الحذف'));
      // The screen keeps its spinner until sign-out leaves it, so don't settle.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(backend.lastBody('/rest/v1/rpc/request_account_deletion'), {'p_reason': 'مش محتاج التطبيق'});
      expect(auth.signOuts, 1);
    });

    testWidgets('cancelling the deletion sends nothing', (tester) async {
      final backend = FakeBackend();
      await pumpScreen(tester, const SettingsScreen(), backend: backend, localized: true);
      await tester.tap(find.text('حذف الحساب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(backend.to('/rest/v1/rpc/request_account_deletion'), isEmpty);
    });

    testWidgets('links open notifications settings and the legal pages', (tester) async {
      final nav = NavProbe();
      await pumpScreen(tester, const SettingsScreen(), backend: FakeBackend(), nav: nav, localized: true);
      await tester.tap(find.text('سياسة الخصوصية'));
      await tester.pumpAndSettle();
      expect(nav.location, '/legal/privacy');
    });
  });

  testWidgets('notification preferences load from the profile and save each switch', (tester) async {
    final backend = FakeBackend({
      '/rest/v1/rpc/get_my_profile': (_) => {
            'id': 'u1',
            'notification_preferences': {'watchlist_matches': true, 'ad_status_updates': true, 'special_offers': false},
          },
    });
    await pumpScreen(tester, const NotificationSettingsScreen(), backend: backend);

    final offers = find.widgetWithText(SwitchListTile, 'عروض خاصة وتحديثات');
    expect(tester.widget<SwitchListTile>(offers).value, isFalse);
    await tester.tap(offers);
    await tester.pumpAndSettle();

    final update = backend.to('/rest/v1/users', method: 'PATCH').single;
    expect(update.url.queryParameters['id'], 'eq.u1');
    expect(backend.lastBody('/rest/v1/users', method: 'PATCH'), {
      'notification_preferences': {'watchlist_matches': true, 'ad_status_updates': true, 'special_offers': true},
    });
    expect(tester.widget<SwitchListTile>(offers).value, isTrue);
  });

  group('notifications center', () {
    final items = [
      {
        'id': 'n1',
        'title': 'إعلان جديد يطابق بحثك',
        'body': 'شقة في المعادي',
        'is_read': false,
        'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'data': {'type': 'watchlist_match', 'ad_id': 'a9'},
      },
      {
        'id': 'n2',
        'title': 'تم قبول إعلانك',
        'body': '',
        'is_read': true,
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'data': {'type': 'ad_status_change'},
      },
    ];

    testWidgets('tapping an unread notification marks it read and opens its ad', (tester) async {
      final backend = FakeBackend({'/rest/v1/rpc/unread_notifications_count': (_) => 1});
      final nav = NavProbe();
      await pumpScreen(tester, const NotificationsScreen(), backend: backend, nav: nav,
          overrides: [notificationsProvider.overrideWith((ref) => Stream.value(items))]);

      expect(find.text('إعلان جديد يطابق بحثك'), findsOneWidget);
      expect(find.text('منذ 5 دقائق'), findsOneWidget);
      expect(find.text('أمس'), findsOneWidget);

      await tester.tap(find.text('إعلان جديد يطابق بحثك'));
      await tester.pumpAndSettle();
      expect(backend.lastBody('/rest/v1/rpc/mark_notifications_read'), {'p_ids': ['n1']});
      expect(nav.location, '/ad/a9');
    });

    testWidgets('"mark all as read" sends no ids', (tester) async {
      final backend = FakeBackend({'/rest/v1/rpc/unread_notifications_count': (_) => 1});
      await pumpScreen(tester, const NotificationsScreen(), backend: backend,
          overrides: [notificationsProvider.overrideWith((ref) => Stream.value(items))]);
      await tester.tap(find.text('تحديد الكل كمقروء'));
      await tester.pumpAndSettle();
      expect(backend.lastBody('/rest/v1/rpc/mark_notifications_read'), {'p_ids': null});
    });

    testWidgets('a guest is asked to sign in', (tester) async {
      await pumpScreen(tester, const NotificationsScreen(), backend: FakeBackend(), userId: null);
      expect(find.text('سجّل الدخول لعرض إشعاراتك'), findsOneWidget);
    });

    testWidgets('an empty list says so', (tester) async {
      await pumpScreen(tester, const NotificationsScreen(), backend: FakeBackend({'/rest/v1/rpc/unread_notifications_count': (_) => 0}),
          overrides: [notificationsProvider.overrideWith((ref) => Stream.value(const []))]);
      expect(find.text('مفيش إشعارات لسه'), findsOneWidget);
    });
  });
}
