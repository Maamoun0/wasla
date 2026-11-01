import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/push_notification_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../saved/providers/saved_ads_provider.dart';

export '../../../core/supabase/supabase_client_provider.dart';

// ── Auth State (Stream) ──────────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) => ref.watch(authRepositoryProvider).authStateChanges);

// ── Current Session ──────────────────────────────────────────────
final currentSessionProvider = Provider<Session?>((ref) => ref.watch(authRepositoryProvider).currentSession);

// ── Current User ID ──────────────────────────────────────────────
final currentUserIdProvider = Provider<String?>((ref) => ref.watch(authRepositoryProvider).currentUserId);

// ── Is Logged In ─────────────────────────────────────────────────
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentSessionProvider) != null;
});

// ── Current User Profile ─────────────────────────────────────────
final currentUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  try {
    return await ref.watch(authRepositoryProvider).myProfile();
  } catch (_) {
    return null;
  }
});

// ── OTP rate limiting ────────────────────────────────────────────
/// Thrown by [AuthNotifier.sendOtp] when Supabase Auth refuses to send another
/// code yet. [retryAfter] is the server's wait time when it gives one.
class OtpRateLimitedException implements Exception {
  const OtpRateLimitedException(this.retryAfter);
  final Duration? retryAfter;

  String get message => retryAfter != null
      ? 'تم إرسال رمز مؤخراً لهذا الرقم. يمكنك طلب رمز جديد بعد ${retryAfter!.inSeconds} ثانية.'
      : 'تجاوزت الحد المسموح لطلب رموز التحقق. حاول مرة أخرى لاحقاً.';

  @override
  String toString() => message;
}

/// Maps Auth's 429 (e.g. "you can only request this after 37 seconds").
OtpRateLimitedException? otpRateLimitFrom(AuthException e) {
  final isRateLimited = e.statusCode == '429' || (e.code?.startsWith('over_') ?? false);
  if (!isRateLimited) return null;
  final seconds = RegExp(r'(\d+)\s*seconds?').firstMatch(e.message)?.group(1);
  return OtpRateLimitedException(seconds != null ? Duration(seconds: int.parse(seconds)) : null);
}

// ── Auth Notifier ─────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AsyncValue.data(null));

  // Send an SMS OTP.
  Future<void> sendOtp(String phone) async {
    state = const AsyncValue.loading();
    try {
      await _repository.sendOtp(phone);
      state = const AsyncValue.data(null);
    } on AuthException catch (e, st) {
      final limited = otpRateLimitFrom(e);
      final error = limited ?? Exception(_translateAuthError(e.message));
      state = AsyncValue.error(error, st);
      throw error;
    } catch (e, st) {
      final error = Exception(_translateAuthError(e.toString()));
      state = AsyncValue.error(error, st);
      throw error;
    }
  }

  // ترجمة رسائل Supabase إلى العربية
  String _translateAuthError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid phone') || m.contains('phone number')) {
      return 'رقم الهاتف غير صحيح. تأكد من كتابة رقم هاتف مصري صحيح (مثال: 01012345678).';
    } else if (m.contains('network') || m.contains('connection') || m.contains('socket')) {
      return 'تعذّر الاتصال بالإنترنت. تحقق من اتصالك وحاول مرة أخرى.';
    } else if (m.contains('sms') || m.contains('provider')) {
      return 'خدمة الرسائل غير متاحة حالياً. حاول مرة أخرى بعد قليل.';
    }
    return 'تعذّر إرسال رمز التحقق. حاول مرة أخرى.';
  }

  // Verify OTP
  Future<void> verifyOtp({
    required String phone,
    required String token,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.verifyOtp(phone: phone, token: token);
      
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
      await _repository.signInWithOAuth(OAuthProvider.google);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Sign in with Facebook (FR-1.2). The provider is enabled in Supabase
  // Auth (Authentication -> Providers -> Facebook) with the Meta app's id.
  Future<void> signInWithFacebook() async {
    state = const AsyncValue.loading();
    try {
      await _repository.signInWithOAuth(OAuthProvider.facebook, scopes: 'email,public_profile');
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
      // Nothing personal stays on the device after sign-out.
      await SavedAdsCache.clearAll();

      await _repository.signOut();
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
    final userId = _repository.currentUserId;
    if (userId == null) return;

    await _repository.updateProfile(userId, {
      if (fullName != null) 'full_name': fullName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (bio != null) 'bio': bio,
      if (cityId != null) 'city_id': cityId,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(ref.watch(authRepositoryProvider)),
);
