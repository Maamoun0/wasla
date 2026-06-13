import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';

class KycIntroScreen extends StatelessWidget {
  const KycIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('توثيق الحساب'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.verified_user_rounded,
              size: 100,
              color: WaslaTheme.secondaryGold,
            ),
            const SizedBox(height: 24),
            Text(
              'الأمان أولاً في وصلة',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'لحماية المجتمع ومنع الاحتيال، نطلب من جميع المستخدمين توثيق هوياتهم بالرقم القومي. بياناتك مشفرة ولا نشاركها مع أحد طبقاً لقانون حماية البيانات الشخصية المصري.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: WaslaTheme.textMuted,
                  ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                // Navigate to next KYC step
                context.go('/home');
              },
              child: const Text('أنا موافق، ابدأ التوثيق'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // Skip for now, go to Home with limited access
                context.go('/home');
              },
              child: const Text('تخطي الآن (صلاحيات محدودة)', style: TextStyle(color: WaslaTheme.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}
