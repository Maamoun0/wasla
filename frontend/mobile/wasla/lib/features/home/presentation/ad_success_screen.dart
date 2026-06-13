import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';

class AdSuccessScreen extends StatelessWidget {
  const AdSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 100, color: WaslaTheme.successGreen),
              const SizedBox(height: 32),
              Text(
                'تم نشر إعلانك بنجاح!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: WaslaTheme.primaryTeal,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              const Text(
                'إعلانك الآن قيد المراجعة السريعة. سنقوم بإشعارك فور تفعيله وظهوره للمستخدمين الآخرين.',
                style: TextStyle(color: WaslaTheme.textMuted, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  context.go('/home');
                },
                child: const Text('العودة للرئيسية'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
