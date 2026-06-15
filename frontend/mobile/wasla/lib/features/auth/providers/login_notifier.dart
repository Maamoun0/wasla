import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';

class LoginState {
  final bool isLoading;
  final String? errorMessage;
  final bool isOtpSent;
  final int cooldownSeconds;
  final bool isVerificationSuccess;

  LoginState({
    this.isLoading = false,
    this.errorMessage,
    this.isOtpSent = false,
    this.cooldownSeconds = 0,
    this.isVerificationSuccess = false,
  });

  LoginState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isOtpSent,
    int? cooldownSeconds,
    bool? isVerificationSuccess,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // نسمح بتصفير رسالة الخطأ
      isOtpSent: isOtpSent ?? this.isOtpSent,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      isVerificationSuccess: isVerificationSuccess ?? this.isVerificationSuccess,
    );
  }
}

class LoginNotifier extends Notifier<LoginState> {
  Timer? _timer;

  @override
  LoginState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return LoginState();
  }

  Future<void> sendOtp(String phone) async {
    if (state.cooldownSeconds > 0) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.sendOtp(phone);
      
      state = state.copyWith(
        isLoading: false,
        isOtpSent: true,
        cooldownSeconds: 60,
      );
      _startTimer();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'فشل إرسال كود التحقق. تأكد من الرقم وحاول مجدداً.',
      );
    }
  }

  Future<void> verifyOtp(String phone, String token) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.verifyOtp(phone, token);
      
      state = state.copyWith(
        isLoading: false,
        isVerificationSuccess: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'كود التحقق غير صحيح أو منتهي الصلاحية.',
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.cooldownSeconds <= 1) {
        timer.cancel();
        state = state.copyWith(cooldownSeconds: 0);
      } else {
        state = state.copyWith(cooldownSeconds: state.cooldownSeconds - 1);
      }
    });
  }
}

/// موفر حالة تسجيل الدخول والـ OTP
final loginStateProvider = NotifierProvider.autoDispose<LoginNotifier, LoginState>(() {
  return LoginNotifier();
});
