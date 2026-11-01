import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/core/router/app_router.dart';
import 'package:wasla/features/auth/providers/auth_provider.dart';
import 'package:wasla/data/repositories/auth_repository.dart';
import 'package:wasla/features/auth/screens/auth_screen.dart';

class _FakeAuth extends AuthNotifier {
  _FakeAuth() 
      : super(AuthRepository(SupabaseClient('http://localhost:1', 'k', authOptions: const AuthClientOptions(autoRefreshToken: false))));
  @override
  Future<void> sendOtp(String phone) async {}
}

void main() {
  group('safeReturnPath', () {
    test('keeps in-app paths with their query', () {
      expect(safeReturnPath('/ad/abc'), '/ad/abc');
      expect(safeReturnPath('/explore?category=2'), '/explore?category=2');
    });

    test('refuses other hosts, schemes and the sign-in pages (no open redirect, no loop)', () {
      for (final bad in [null, '', 'ad/abc', '//evil.example/x', 'https://evil.example', 'wasla://x', '/auth', '/auth/otp?phone=1']) {
        expect(safeReturnPath(bad), isNull, reason: '$bad');
      }
    });
  });

  group('authRedirect', () {
    test('a guest on a protected page goes to sign-in, remembering the page', () {
      final to = authRedirect(isLoggedIn: false, matchedLocation: '/profile/my-ads', uri: Uri.parse('/profile/my-ads'));
      expect(to, '/auth?from=%2Fprofile%2Fmy-ads');
    });

    test('signed in on the sign-in page (Google returns there): back to the page', () {
      expect(authRedirect(isLoggedIn: true, matchedLocation: '/auth', uri: Uri.parse('/auth?from=%2Fad%2Fabc')), '/ad/abc');
      expect(authRedirect(isLoggedIn: true, matchedLocation: '/auth', uri: Uri.parse('/auth')), AppRoutes.home);
      expect(authRedirect(isLoggedIn: true, matchedLocation: '/auth', uri: Uri.parse('/auth?from=https://evil.example')), AppRoutes.home);
    });

    test('public pages and signed-in users elsewhere stay', () {
      expect(authRedirect(isLoggedIn: false, matchedLocation: '/ad/abc', uri: Uri.parse('/ad/abc')), isNull);
      expect(authRedirect(isLoggedIn: true, matchedLocation: '/auth/otp', uri: Uri.parse('/auth/otp')), isNull,
          reason: 'the OTP screen decides itself (profile setup for new users)');
    });
  });

  testWidgets('the OTP step keeps the page to return to', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? otpLocation;
    final router = GoRouter(initialLocation: '/auth?from=%2Fad%2Fabc', routes: [
      GoRoute(path: AppRoutes.auth, builder: (_, s) => AuthScreen(returnTo: safeReturnPath(s.uri.queryParameters['from']))),
      GoRoute(path: AppRoutes.otp, builder: (_, s) {
        otpLocation = s.uri.toString();
        return const Scaffold(body: Text('otp'));
      }),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [authNotifierProvider.overrideWith((ref) => _FakeAuth())],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '01012345678');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle();

    final uri = Uri.parse(otpLocation!);
    expect(uri.queryParameters['from'], '/ad/abc');
    expect(uri.queryParameters['phone'], '+201012345678');
  });
}
