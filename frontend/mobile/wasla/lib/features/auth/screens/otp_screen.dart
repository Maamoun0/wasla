import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});
  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  int _secondsLeft = 60;
  Timer? _timer;
  String _otpValue = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verify() async {
    if (_otpValue.length < 6) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).verifyOtp(
        phone: widget.phone,
        token: _otpValue,
      );

      if (!mounted) return;

      // Check if new user (needs profile setup)
      final profile = await ref.read(currentUserProvider.future);
      if (profile?['full_name'] == null || (profile!['full_name'] as String).isEmpty) {
        context.go(AppRoutes.profileSetup);
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'رمز التحقق غير صحيح. حاول مرة أخرى.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _otpController.clear();
        setState(() => _otpValue = '');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authNotifierProvider.notifier).sendOtp(widget.phone);
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم إعادة إرسال الرمز', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // ── Icon ─────────────────────────────────────────
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.primary600,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),

            // ── Title ─────────────────────────────────────────
            Text(
              AppStrings.verifyOtp,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.neutral500,
                ),
                children: [
                  const TextSpan(text: 'تم إرسال رمز التحقق إلى '),
                  TextSpan(
                    text: widget.phone,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral900,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // ── OTP Input ─────────────────────────────────────
            PinCodeTextField(
              appContext: context,
              length: 6,
              controller: _otpController,
              keyboardType: TextInputType.number,
              textStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.primary600,
              ),
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(12),
                fieldHeight: 56,
                fieldWidth: 46,
                activeColor: AppColors.primary600,
                activeFillColor: AppColors.primary50,
                selectedColor: AppColors.primary600,
                selectedFillColor: AppColors.primary50,
                inactiveColor: AppColors.neutral200,
                inactiveFillColor: AppColors.white,
                errorBorderColor: AppColors.error,
              ),
              enableActiveFill: true,
              animationType: AnimationType.fade,
              cursorColor: AppColors.primary600,
              onChanged: (val) => setState(() => _otpValue = val),
              onCompleted: (val) {
                setState(() => _otpValue = val);
                _verify();
              },
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            ),
            const SizedBox(height: 32),

            // ── Verify Button ─────────────────────────────────
            PrimaryButton(
              label: AppStrings.confirm,
              isLoading: _isLoading,
              isDisabled: _otpValue.length < 6,
              onPressed: _verify,
            ),
            const SizedBox(height: 24),

            // ── Resend ────────────────────────────────────────
            Center(
              child: _secondsLeft > 0
                  ? Text.rich(
                      TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.neutral500,
                        ),
                        children: [
                          const TextSpan(text: 'إعادة الإرسال خلال '),
                          TextSpan(
                            text: '${_secondsLeft}ث',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : TextButton(
                      onPressed: _resend,
                      child: Text(
                        AppStrings.resendOtp,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary600,
                          fontSize: 15,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
