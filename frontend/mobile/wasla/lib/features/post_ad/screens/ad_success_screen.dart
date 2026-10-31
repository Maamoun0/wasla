import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../providers/post_ad_wizard_provider.dart';

class AdSuccessScreen extends ConsumerWidget {
  const AdSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Extract the created ad ID from the URL query parameter
    final adId = GoRouterState.of(context).uri.queryParameters['id'];

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl, vertical: AppSizes.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                // Lottie Success Animation (With Bulletproof Fallback)
                Center(
                  child: Lottie.asset(
                    AppAssets.successAnim,
                    width: 200,
                    height: 200,
                    repeat: false,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 72,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSizes.xxl),

                // Success Title
                const Text(
                  'تم نشر إعلانك بنجاح!',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutral900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.sm),

                // Success Subtitle
                const Text(
                  'إعلانك وصل لفريق المراجعة. هيظهر للناس أول ما يتوافق عليه، وهيوصلك إشعار بالنتيجة.',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: AppColors.neutral600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),

                // Action Buttons
                if (adId != null && adId.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to the newly created ad details
                      context.go('/ad/$adId');
                    },
                    icon: const Icon(Icons.visibility_rounded, size: 20),
                    label: const Text('عرض الإعلان المنشور', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: AppSizes.md),

                OutlinedButton.icon(
                  onPressed: () {
                    // Reset the wizard and start posting another ad
                    ref.read(postAdWizardProvider.notifier).reset();
                    context.go(AppRoutes.postCategory);
                  },
                  icon: const Icon(Icons.add_box_rounded, size: 20),
                  label: const Text('نشر إعلان آخر', style: TextStyle(fontFamily: 'Cairo')),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary600),
                    foregroundColor: AppColors.primary600,
                  ),
                ),
                const SizedBox(height: AppSizes.md),

                TextButton.icon(
                  onPressed: () {
                    // Reset and return home
                    ref.read(postAdWizardProvider.notifier).reset();
                    context.go(AppRoutes.home);
                  },
                  icon: const Icon(Icons.home_rounded, size: 20),
                  label: const Text('العودة للرئيسية', style: TextStyle(fontFamily: 'Cairo')),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.neutral600,
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
