import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/features/auth/providers/auth_provider.dart';
import 'package:wasla/data/repositories/auth_repository.dart';
import 'package:wasla/features/auth/screens/auth_screen.dart';

class _RecordingAuth extends AuthNotifier {
  _RecordingAuth() 
      : super(AuthRepository(SupabaseClient('http://localhost:1', 'k', authOptions: const AuthClientOptions(autoRefreshToken: false))));
  final calls = <String>[];
  @override
  Future<void> signInWithFacebook() async => calls.add('facebook');
  @override
  Future<void> signInWithGoogle() async => calls.add('google');
}

void main() {
  testWidgets('the Facebook button starts the Facebook sign-in (FR-1.2)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _RecordingAuth();
    await tester.pumpWidget(ProviderScope(
      overrides: [authNotifierProvider.overrideWith((ref) => auth)],
      child: const MaterialApp(home: AuthScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تابع بـ Facebook'));
    await tester.pump();
    await tester.tap(find.text('تابع بـ Google'));
    await tester.pump();
    expect(auth.calls, ['facebook', 'google']);
  });
}
