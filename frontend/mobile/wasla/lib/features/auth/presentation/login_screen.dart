import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';
import '../providers/login_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submitPhone() async {
    if (_formKey.currentState?.validate() ?? false) {
      final phone = _phoneController.text.trim();
      
      // استدعاء إرسال الـ OTP عبر الموفر
      await ref.read(loginStateProvider.notifier).sendOtp(phone);
      
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
      } else if (loginState.isOtpSent) {
        if (mounted) {
          context.go('/verify-otp', extra: phone);
        }
      }
    }
  }

  String? _validateEgyptianPhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال رقم الهاتف';
    }
    final trimmed = value.trim();
    // التحقق من أن الرقم يتوافق مع أرقام شبكات الاتصال المصرية (010, 011, 012, 015) وبطول 11 رقماً
    final regExp = RegExp(r'^01[0125][0-9]{8}$');
    if (!regExp.hasMatch(trimmed)) {
      return 'الرجاء إدخال رقم هاتف مصري صحيح (مثال: 01xxxxxxxxx)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الدخول'),
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
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: WaslaTheme.primaryTealLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.handshake_rounded,
                      size: 64,
                      color: WaslaTheme.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'مرحباً بك في وصلة',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: WaslaTheme.primaryTeal,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'أدخل رقم هاتفك لتسجيل الدخول أو إنشاء حساب جديد وتلقي رمز التحقق OTP.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: WaslaTheme.textMuted,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  validator: _validateEgyptianPhone,
                  enabled: !loginState.isLoading,
                  decoration: const InputDecoration(
                    hintText: '01xxxxxxxxx',
                    labelText: 'رقم الهاتف المحمول',
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loginState.isLoading ? null : _submitPhone,
                  child: loginState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('إرسال رمز التحقق'),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('أو سجل عبر', style: TextStyle(color: WaslaTheme.textMuted)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: loginState.isLoading ? null : () {},
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('جوجل'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: loginState.isLoading ? null : () {},
                        icon: const Icon(Icons.facebook, size: 20),
                        label: const Text('فيسبوك'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
