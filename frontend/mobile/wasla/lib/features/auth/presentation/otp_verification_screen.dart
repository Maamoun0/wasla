import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  const OtpVerificationScreen({super.key, required this.phone});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();

  void _verifyOtp() {
    final otp = _otpController.text.trim();
    if (otp.length == 6) {
      // Navigate to KYC or Home depending on verification status
      context.go('/kyc-intro');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق من الهاتف'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Text(
              'أدخل الرمز السري',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'أرسلنا لك رسالة نصية تحتوي على رمز التحقق إلى الرقم\n${widget.phone}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: WaslaTheme.textMuted,
                  ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(letterSpacing: 8, fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '000000',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _verifyOtp,
              child: const Text('تأكيد الرمز'),
            ),
          ],
        ),
      ),
    );
  }
}
