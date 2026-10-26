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
  const OtpScreen({super.key, required this.phone, this.initialWaitSeconds});
  final String phone;

  /// Seconds before a new code may be requested (from the server's limit).
  final int? initialWaitSeconds;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  // Matches Auth's one-code-per-number-per-minute limit (supabase/config.toml).
  static const _resendInterval = 60;
  int _secondsLeft = _resendInterval;
  Timer? _timer;
  String _otpValue = '';

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.initialWaitSeconds ?? _resendInterval;
    _tick();
  }

  void _startTimer([int seconds = _resendInterval]) {
    setState(() => _secondsLeft = seconds);
    _tick();
  }

  void _tick() {
    _timer?.cancel();
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

      // Record Legal Acceptance (Piece 2.2)
      try {
        final client = ref.read(supabaseClientProvider);
        final userId = ref.read(currentUserIdProvider);
        if (userId != null) {
          await client.from('legal_acceptances').upsert({
            'user_id': userId,
            'policy_version': 'v1.0',
            'accepted_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id, policy_version');
        }
      } catch (e) {
        debugPrint('Non-critical: Failed to record legal acceptance: $e');
      }

      // Check if new user (needs profile setup)
      final profile = await ref.read(currentUserProvider.future);
      if (!mounted) return;

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
    } on OtpRateLimitedException catch (e) {
      // The server decides when the next code may be sent.
      _startTimer(e.retryAfter?.inSeconds ?? _resendInterval);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message, style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.isNotEmpty ? msg : 'فشل إعادة إرسال الرمز', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
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
                            text: '$_secondsLeftث',
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
