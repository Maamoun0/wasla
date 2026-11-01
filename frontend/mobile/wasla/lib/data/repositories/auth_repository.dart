import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client_provider.dart';

/// Sign-in, the session and the signed-in user's own profile (Rule 4.1).
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  Session? get currentSession => _client.auth.currentSession;
  String? get currentUserId => _client.auth.currentUser?.id;

  /// phone/email/user_type are only readable by the owner through this RPC.
  Future<Map<String, dynamic>?> myProfile() => _client.rpc('get_my_profile').maybeSingle();

  /// Limits are enforced by Supabase Auth itself (one code per number per
  /// minute, hourly project cap, per-IP request limits).
  Future<void> sendOtp(String phone) => _client.auth.signInWithOtp(phone: phone, shouldCreateUser: true);

  Future<void> verifyOtp({required String phone, required String token}) =>
      _client.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);

  Future<void> signInWithOAuth(OAuthProvider provider, {String? scopes}) => _client.auth.signInWithOAuth(
        provider,
        redirectTo: 'wasla://login-callback',
        scopes: scopes,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

  Future<void> signOut() => _client.auth.signOut();

  Future<void> updateProfile(String userId, Map<String, dynamic> values) =>
      _client.from('users').update(values).eq('id', userId);

  /// Uploads the profile photo and returns its URL. Storage policies only allow
  /// writes inside the user's own `{uid}/` folder.
  Future<String> uploadAvatar(String userId, Uint8List bytes) async {
    final path = '$userId/avatar.jpg';
    await _client.storage
        .from('avatars')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
    // Same object name on every change: version the URL so caches pick up the new photo.
    return '${_client.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Hides the account and its ads now, blocks sign-in, and schedules the
  /// permanent purge 30 days later.
  Future<void> requestAccountDeletion(String? reason) =>
      _client.rpc('request_account_deletion', params: {'p_reason': reason});
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseClientProvider)));
