import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Future<void> sendOtp(String phone) async {
    // تنسيق رقم الهاتف ليطابق الصيغة المطلوبة في مصر (+20) إن لم يكن منسقاً بالفعل
    var formattedPhone = phone.trim();
    if (!formattedPhone.startsWith('+')) {
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '+20${formattedPhone.substring(1)}';
      } else {
        formattedPhone = '+20$formattedPhone';
      }
    }
    
    await _client.auth.signInWithOtp(
      phone: formattedPhone,
    );
  }

  @override
  Future<AuthResponse> verifyOtp(String phone, String token) async {
    var formattedPhone = phone.trim();
    if (!formattedPhone.startsWith('+')) {
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '+20${formattedPhone.substring(1)}';
      } else {
        formattedPhone = '+20$formattedPhone';
      }
    }

    return await _client.auth.verifyOTP(
      phone: formattedPhone,
      token: token,
      type: OtpType.sms,
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> updateProfile({
    required String fullName,
    int? cityId,
    String? avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('المستخدم غير مسجل دخوله');

    final updates = {
      'id': user.id,
      'full_name': fullName,
      if (cityId != null) 'city_id': cityId,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _client.from('users').upsert(updates);
  }
}
