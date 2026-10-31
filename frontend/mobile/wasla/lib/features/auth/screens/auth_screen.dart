import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/wasla_logo.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  // Consent must be given actively: never pre-ticked.
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhone(String raw) {
    String digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('20') && digits.length >= 12) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+20$digits';
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      _showError('يجب الموافقة على شروط الاستخدام وسياسة الخصوصية للمتابعة');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = _formatPhone(_phoneController.text.trim());
      await ref.read(authNotifierProvider.notifier).sendOtp(phone);

      if (mounted) {
        context.push('${AppRoutes.otp}?phone=${Uri.encodeComponent(phone)}');
      }
    } on OtpRateLimitedException catch (e) {
      // A code was sent to this number moments ago: continue to the code entry
      // screen with the server's remaining wait instead of failing.
      final wait = e.retryAfter;
      if (mounted && wait != null) {
        final phone = _formatPhone(_phoneController.text.trim());
        context.push('${AppRoutes.otp}?phone=${Uri.encodeComponent(phone)}&wait=${wait.inSeconds}');
      } else if (mounted) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        _showError(msg.isNotEmpty ? msg : 'حدث خطأ في إرسال الرمز. تحقق من رقم هاتفك وحاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '⚠️ خطأ',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        ),
        content: Text(
          msg,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),

                // ── Logo ──────────────────────────────────────
                const Center(
                  child: WaslaLogoFull(
                    size: 48,
                    variant: WaslaLogoVariant.color,
                  ),
                ),
                const SizedBox(height: 40),

                // ── Title ─────────────────────────────────────
                Text(
                  AppStrings.welcome,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'أدخل رقم هاتفك للمتابعة',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.neutral500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // ── Phone Field ───────────────────────────────
                _PhoneField(controller: _phoneController),
                const SizedBox(height: 8),

                // ── Test Mode Hint ────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: const Text(
                    '🧪 للاختبار: استخدم 01012345678 ورمز التحقق 123456',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Color(0xFF92400E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Terms Checkbox ─────────────────────────────────────
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                        activeColor: AppColors.primary600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'أوافق على ',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.neutral700),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/legal/terms'),
                            child: const Text(
                              'شروط الاستخدام',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: AppColors.primary600,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(
                            ' و ',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.neutral700),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/legal/privacy'),
                            child: const Text(
                              'سياسة الخصوصية',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: AppColors.primary600,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Send OTP Button ───────────────────────────
                PrimaryButton(
                  label: AppStrings.sendOtp,
                  isLoading: _isLoading,
                  onPressed: _sendOtp,
                ),
                const SizedBox(height: 28),

                // ── Divider ───────────────────────────────────
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        AppStrings.orContinueWith,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Social Login ──────────────────────────────
                _SocialLoginButton(
                  icon: Icons.g_mobiledata_rounded,
                  label: 'تابع بـ Google',
                  onPressed: () async {
                    try {
                      await ref
                          .read(authNotifierProvider.notifier)
                          .signInWithGoogle();
                    } catch (_) {
                      _showError(AppStrings.errorGeneral);
                    }
                  },
                ),
                const SizedBox(height: 28),

                // ── Guest Mode ────────────────────────────────
                TextButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: Text(
                    AppStrings.browseAsGuest,
                    style: const TextStyle(
                      color: AppColors.neutral500,
                      fontFamily: 'Cairo',
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Terms ─────────────────────────────────────
                Text(
                  'بالمتابعة توافق على شروط الاستخدام وسياسة الخصوصية',
                  style: Theme.of(context).textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Phone Field ───────────────────────────────────────────────────
class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 11,
      style: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      ),
      decoration: InputDecoration(
        hintText: AppStrings.phoneHint,
        counterText: '',
        prefixIcon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: const Text(
            '🇪🇬 +20',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral700,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      validator: (val) {
        if (val == null || val.isEmpty) return AppStrings.errorRequired;
        final digits = val.replaceAll(RegExp(r'\D'), '');
        if (digits.length < 10 || digits.length > 11) {
          return AppStrings.errorInvalidPhone;
        }
        return null;
      },
    );
  }
}

// ── Social Login Button ───────────────────────────────────────────
class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.neutral700,
        side: const BorderSide(color: AppColors.neutral200, width: 1.5),
        backgroundColor: AppColors.white,
      ),
    );
  }
}
