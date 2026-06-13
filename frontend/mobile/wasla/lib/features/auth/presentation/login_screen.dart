import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();

  void _submitPhone() {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      // Navigate to OTP verification and pass the phone number
      context.go('/verify-otp', extra: phone);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الدخول'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Text(
              'مرحباً بك في وصلة',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'أدخل رقم هاتفك للمتابعة. سنقوم بإرسال رمز تحقق.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: WaslaTheme.textMuted,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                hintText: 'رقم الهاتف (مثال: 01xxxxxxxxx)',
                prefixIcon: Icon(Icons.phone_android),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitPhone,
              child: const Text('إرسال رمز التحقق'),
            ),
          ],
        ),
      ),
    );
  }
}
