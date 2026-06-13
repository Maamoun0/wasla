import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  /// البث المباشر لتغيرات حالة المصادقة (دخول/خروج/تغيير التوكن)
  Stream<AuthState> get authStateChanges;

  /// المستخدم الحالي المسجل إن وجد
  User? get currentUser;

  /// إرسال رمز التحقق OTP إلى هاتف المستخدم
  Future<void> sendOtp(String phone);

  /// التحقق من رمز OTP وإتمام تسجيل الدخول
  Future<AuthResponse> verifyOtp(String phone, String token);

  /// تسجيل الخروج من الحساب
  Future<void> signOut();

  /// تحديث بيانات الملف الشخصي للمستخدم
  Future<void> updateProfile({
    required String fullName,
    int? cityId,
    String? avatarUrl,
  });
}
