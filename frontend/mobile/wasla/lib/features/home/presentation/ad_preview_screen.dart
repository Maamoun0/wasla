import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';

class AdPreviewScreen extends StatelessWidget {
  const AdPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة الإعلان'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('الخطوة الأخيرة: تأكيد الإعلان والمعاينة', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEAE4DA)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('عنوان الإعلان التجريبي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('15,000 جنيه مصري', style: TextStyle(fontSize: 16, color: WaslaTheme.primaryTeal, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('هذا وصف تجريبي للإعلان لمراجعة طريقة التنسيق والظهور للمشتري بالشكل اللائق.'),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                context.go('/post/success');
              },
              child: const Text('نشر الإعلان الآن'),
            ),
          ],
        ),
      ),
    );
  }
}
