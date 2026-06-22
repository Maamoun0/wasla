import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../providers/subscription_controller.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionControllerProvider);
    final notifier = ref.read(subscriptionControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3), // Egyptian Sand Background
      appBar: AppBar(
        title: const Text(
          'خطط الاشتراكات التجارية',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Builder(
        builder: (context) {
          if (state.status == SubscriptionScreenStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary500),
            );
          }

          if (state.status == SubscriptionScreenStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage ?? 'حدث خطأ في تحميل باقات الاشتراك',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => notifier.init(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                  ),
                ],
              ),
            );
          }

          final activePlanId = state.activeSubscription?['plan_id'] as int?;
          final activeSubExpiry = state.activeSubscription?['expires_at'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active Sub Info Card
                if (state.activeSubscription != null)
                  Container(
                    margin: const EdgeInsets.bottom: 24,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary500.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary500.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: AppColors.primary500, size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'خطتك الحالية: ${state.activeSubscription!['subscription_plans']?['name_ar'] ?? ''}',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.primary500,
                                ),
                              ),
                              if (activeSubExpiry != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'تاريخ الانتهاء: ${intl.DateFormat('yyyy/MM/dd').format(DateTime.parse(activeSubExpiry))}',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const Text(
                  'اختر باقة الاشتراك المناسبة لأعمالك',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary500,
                  ),
                ),
                const SizedBox(height: 16),

                // List of plans
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.plans.length,
                  itemBuilder: (context, index) {
                    final plan = state.plans[index];
                    final planId = plan['id'] as int;
                    
                    // plan_id == 1 is the 'free' plan from schema seeds
                    final isFreePlan = planId == 1;
                    
                    // Check if this plan is the user's currently active subscription
                    final isActive = activePlanId == planId || (state.activeSubscription == null && isFreePlan);
                    final price = (plan['price_monthly'] as num?)?.toDouble() ?? 0.0;
                    final maxAds = plan['max_ads'] as int? ?? 5;
                    final maxImages = plan['max_images_per_ad'] as int? ?? 4;
                    final features = plan['features'] as Map<String, dynamic>? ?? {};

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive ? AppColors.accent500 : AppColors.neutral200,
                          width: isActive ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section of Plan Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.accent500.withOpacity(0.08) : Colors.transparent,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(14),
                                topRight: Radius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isFreePlan
                                          ? Icons.badge_outlined
                                          : plan['name'] == 'business'
                                              ? Icons.business_center_rounded
                                              : Icons.workspace_premium_rounded,
                                      color: isActive ? AppColors.accent500 : AppColors.primary500,
                                      size: 26,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      plan['name_ar'] ?? '',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent500,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'نشط حالياً',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Content & Features Section
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Price
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      price == 0 ? 'مجاناً' : '${price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
                                        color: AppColors.primary500,
                                      ),
                                    ),
                                    if (price > 0) ...[
                                      const SizedBox(width: 4),
                                      const Text(
                                        'ج.م / شهرياً',
                                        style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),

                                // Feature item list
                                _buildFeatureItem(Icons.done_all_rounded, 'الحد الأقصى للإعلانات النشطة: ${maxAds == 999 ? 'غير محدود' : maxAds}'),
                                _buildFeatureItem(Icons.done_all_rounded, 'الصور لكل إعلان: $maxImages صور'),
                                if (features['can_boost'] == true)
                                  _buildFeatureItem(Icons.flash_on_rounded, 'تفعيل تمويل وتعزيز الإعلانات', iconColor: AppColors.accent500),
                                if (features['verified_badge'] == true)
                                  _buildFeatureItem(Icons.verified_rounded, 'شارة الحساب الموثق التلقائية', iconColor: Colors.blue),
                                if (features['analytics'] == true)
                                  _buildFeatureItem(Icons.analytics_rounded, 'لوحة تحليلات وإحصائيات متقدمة لإعلاناتك'),
                                if (features['priority_support'] == true)
                                  _buildFeatureItem(Icons.support_agent_rounded, 'دعم فني سريع وأولوية في التواصل'),

                                const SizedBox(height: 20),

                                // Action Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton(
                                    onPressed: isActive || state.isVerifying
                                        ? null
                                        : () => _handleSubscriptionRequest(context, ref, plan),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary500,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      disabledBackgroundColor: AppColors.neutral200,
                                    ),
                                    child: state.isVerifying
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : Text(
                                            isActive
                                                ? 'خطة الاشتراك الحالية'
                                                : isFreePlan
                                                    ? 'العودة للمجاني'
                                                    : 'اشترك الآن',
                                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                if (state.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[100]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, {Color iconColor = AppColors.primary500}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // Handle subscribe button click
  Future<void> _handleSubscriptionRequest(BuildContext context, WidgetRef ref, Map<String, dynamic> selectedPlan) async {
    final controller = ref.read(subscriptionControllerProvider.notifier);
    
    // Check if the user has an active paid subscription
    if (controller.hasActivePaidSubscription()) {
      // Show refund disclaimer warning dialog in Arabic
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.accent500),
              SizedBox(width: 8),
              Text('تنبيه ترقية الاشتراك', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'سيتم تطبيق الخطة الجديدة فوراً، بدون استرداد للمدة المتبقية من خطتك الحالية.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('موافق، استمر', style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary500, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    // Call stub and transition to payment
    final result = await controller.prepareUpgrade(selectedPlan);
    if (result != null && context.mounted) {
      final success = await context.push<bool?>(
        AppRoutes.paymentWebView,
        extra: {
          'paymentUrl': result['payment_url'],
          'transactionId': result['transaction_id'],
          'paymentType': 'subscription',
          'referenceId': selectedPlan['id'].toString(),
        },
      );

      if (success == true) {
        controller.fetchActiveSubscription();
      }
    }
  }
}
