import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate loading and redirect to login
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaslaTheme.primaryTeal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.handshake_rounded,
              size: 80,
              color: WaslaTheme.surfaceWhite,
            ),
            const SizedBox(height: 16),
            Text(
              'وصلة',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: WaslaTheme.surfaceWhite,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'خدمات وإعلانات موثوقة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: WaslaTheme.secondaryGoldLight,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
