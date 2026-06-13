import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/repositories/supabase_auth_repository.dart';
import '../domain/repositories/auth_repository.dart';

/// موفر العميل الخاص بـ Supabase
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// موفر مستودع المصادقة
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client);
});

/// بث حي لحالة المصادقة (دخول/خروج)
final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

/// موفر المستخدم الحالي
final currentUserProvider = Provider<User?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  // نقوم بمراقبة authStateProvider لنضمن إعادة بناء الموفر عند تسجيل الدخول/الخروج
  ref.watch(authStateProvider);
  return repo.currentUser;
});
