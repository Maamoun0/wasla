import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';
import '../providers/login_notifier.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpVerificationScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _submitOtp() async {
    if (_formKey.currentState?.validate() ?? false) {
      final code = _otpController.text.trim();
      
      await ref.read(loginStateProvider.notifier).verifyOtp(widget.phone, code);
      
      final loginState = ref.read(loginStateProvider);
      
      if (loginState.errorMessage != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loginState.errorMessage!),
              backgroundColor: WaslaTheme.errorRed,
            ),
          );
        }
      } else if (loginState.isVerificationSuccess) {
        if (mounted) {
          // التوجيه لإكمال إعداد الملف الشخصي عند الدخول الناجح لأول مرة
          context.go('/auth/setup');
        }
      }
    }
  }

  void _resendCode() {
    ref.read(loginStateProvider.notifier).sendOtp(widget.phone);
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('رمز التحقق'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  'تأكيد الرمز',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: WaslaTheme.primaryTeal,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'لقد أرسلنا كود تحقق مكوناً من 6 أرقام إلى الرقم التالي:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: WaslaTheme.textMuted,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.phone,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('تعديل الرقم'),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  enabled: !loginState.isLoading,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                  ),
                  decoration: const InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال الكود';
                    }
                    if (value.trim().length != 6) {
                      return 'كود التحقق يجب أن يكون مكوناً من 6 أرقام';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loginState.isLoading ? null : _submitOtp,
                  child: loginState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('تأكيد وتسجيل الدخول'),
                ),
                const SizedBox(height: 32),
                Center(
                  child: loginState.cooldownSeconds > 0
                      ? Text(
                          'إعادة إرسال الكود خلال ${loginState.cooldownSeconds} ثانية',
                          style: const TextStyle(color: WaslaTheme.textMuted),
                        )
                      : TextButton(
                          onPressed: loginState.isLoading ? null : _resendCode,
                          child: const Text(
                            'إعادة إرسال رمز التحقق (OTP)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
