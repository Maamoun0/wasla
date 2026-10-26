import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/push_notification_service.dart';

// ── Supabase Client Provider ─────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

// ── Auth State (Stream) ──────────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

// ── Current Session ──────────────────────────────────────────────
final currentSessionProvider = Provider<Session?>((ref) {
  return Supabase.instance.client.auth.currentSession;
});

// ── Current User ID ──────────────────────────────────────────────
final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

// ── Is Logged In ─────────────────────────────────────────────────
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentSessionProvider) != null;
});

// ── Current User Profile ─────────────────────────────────────────
final currentUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final client = ref.watch(supabaseClientProvider);
  try {
    final response = await client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return response;
  } catch (_) {
    return null;
  }
});

// ── Auth Notifier ─────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final SupabaseClient _client;

  AuthNotifier(this._client) : super(const AsyncValue.data(null));

  // Send OTP to phone number via Supabase Auth & Edge Function
  Future<void> sendOtp(String phone) async {
    state = const AsyncValue.loading();
    try {
      // 1. Try requesting OTP via Edge Function (supports rate limiting & logging)
      try {
        final res = await _client.functions.invoke(
          'request-otp',
          body: {'phone_number': phone},
        );
        if (res.status == 200 && res.data != null && res.data['success'] == true) {
          state = const AsyncValue.data(null);
          return;
        } else if (res.status == 429) {
          final msg = res.data?['message'] ?? 'تجاوزت الحد المسموح به لطلب رمز التحقق.';
          state = AsyncValue.error(Exception(msg), StackTrace.current);
          throw Exception(msg);
        } else if (res.data != null && res.data['error'] != null) {
          final errorStr = res.data['error'].toString();
          if (errorStr.contains('SMS provider') || errorStr.contains('not configured')) {
            throw AuthException(errorStr);
          }
        }
      } catch (fe) {
        if (fe is AuthException || (fe is Exception && fe.toString().contains('تجاوزت'))) {
          rethrow;
        }
        // Fallback to direct SDK call if Edge Function is not deployed
      }

      // 2. Direct Supabase Auth Call (Fallback)
      await _client.auth.signInWithOtp(
        phone: phone,
        shouldCreateUser: true,
      );
      state = const AsyncValue.data(null);
    } on AuthException catch (e, st) {
      String arabicMsg = _translateAuthError(e.message);
      state = AsyncValue.error(Exception(arabicMsg), st);
      throw Exception(arabicMsg);
    } catch (e, st) {
      final rawMsg = e.toString().replaceFirst('Exception: ', '');
      String arabicMsg = _translateAuthError(rawMsg);
      state = AsyncValue.error(Exception(arabicMsg), st);
      throw Exception(arabicMsg);
    }
  }

  // ترجمة رسائل Supabase إلى العربية
  String _translateAuthError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'تجاوزت الحد المسموح به. انتظر 3 دقائق وحاول مرة أخرى.';
    } else if (m.contains('invalid phone') || m.contains('phone number')) {
      return 'رقم الهاتف غير صحيح. تأكد من كتابة رقم هاتف مصري صحيح (مثال: 01012345678).';
    } else if (m.contains('network') || m.contains('connection')) {
      return 'تعذّر الاتصال بالإنترنت. تحقق من اتصالك وحاول مرة أخرى.';
    } else if (m.contains('sms') || m.contains('twilio') || m.contains('provider') || m.contains('not configured')) {
      return 'خدمة الرسائل النصية (SMS) غير مفعّلة في لوحة Supabase. لتجربة الأرقام الحقيقية يجب ربط حساب Twilio في Supabase Dashboard → Auth → Phone. يمكنك حالياً استخدام رقم الاختبار: 01012345678 برمز 123456.';
    }
    return 'حدث خطأ: $msg';
  }

  // Verify OTP
  Future<void> verifyOtp({
    required String phone,
    required String token,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      
      // Sync FCM token after successful login (Piece 1.3)
      await PushNotificationService.syncToken();
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Sign in with Google
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'wasla://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      // Delete FCM token before signing out (Piece 1.3)
      await PushNotificationService.deleteToken();
      
      await _client.auth.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Update profile
  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? bio,
    int? cityId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('users').update({
      if (fullName != null) 'full_name': fullName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (bio != null) 'bio': bio,
      if (cityId != null) 'city_id': cityId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(ref.watch(supabaseClientProvider)),
);
