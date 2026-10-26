import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../providers/boost_controller.dart';

class BoostAdScreen extends ConsumerStatefulWidget {
  const BoostAdScreen({super.key, required this.adId});
  final String adId;

  @override
  ConsumerState<BoostAdScreen> createState() => _BoostAdScreenState();
}

class _BoostAdScreenState extends ConsumerState<BoostAdScreen> {
  @override
  void initState() {
    super.initState();
    // After build frame, pre-select the ad if adId is valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.adId.isNotEmpty && widget.adId != 'all') {
        final state = ref.read(boostControllerProvider);
        final ad = state.userAds.firstWhere(
          (element) => element['id'] == widget.adId,
          orElse: () => {},
        );
        if (ad.isNotEmpty) {
          ref.read(boostControllerProvider.notifier).selectAd(ad);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(boostControllerProvider);
    final notifier = ref.read(boostControllerProvider.notifier);

    // If pre-selected ad is not found in state yet (loading), try setting it when userAds updates
    if (widget.adId.isNotEmpty && widget.adId != 'all' && state.selectedAd == null && state.userAds.isNotEmpty) {
      final ad = state.userAds.firstWhere(
        (element) => element['id'] == widget.adId,
        orElse: () => {},
      );
      if (ad.isNotEmpty) {
        Future.microtask(() => notifier.selectAd(ad));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3), // Egyptian Sand Background
      appBar: AppBar(
        title: const Text(
          'ترقية وتعزيز الإعلان',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Builder(
        builder: (context) {
          if (state.status == BoostScreenStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary500),
            );
          }

          if (state.status == BoostScreenStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage ?? 'حدث خطأ في تحميل البيانات',
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. SELECT AD SECTION
                const Text(
                  '1. اختر الإعلان المراد ترويجه',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary500,
                  ),
                ),
                const SizedBox(height: 10),
                if (state.userAds.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.neutral200),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.accent500, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'ليس لديك أي إعلانات نشطة مؤهلة للترقية حالياً.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.neutral200),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          value: state.selectedAd,
                          hint: const Text(
                            'اختر من إعلاناتك النشطة...',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 14),
                          ),
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary500),
                          items: state.userAds.map((ad) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: ad,
                              child: Text(
                                ad['title'] ?? 'بدون عنوان',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: notifier.selectAd,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // 2. SELECT PACKAGE SECTION
                const Text(
                  '2. اختر باقة التعزيز المناسبة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary500,
                  ),
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.packages.length,
                  itemBuilder: (context, index) {
                    final package = state.packages[index];
                    final isSelected = state.selectedPackage == package;

                    IconData getIcon() {
                      switch (package.type) {
                        case 'featured':
                          return Icons.workspace_premium_rounded;
                        case 'urgent':
                          return Icons.error_rounded;
                        default:
                          return Icons.flash_on_rounded;
                      }
                    }

                    Color getIconColor() {
                      switch (package.type) {
                        case 'featured':
                          return AppColors.accent500; // Egyptian Gold
                        case 'urgent':
                          return Colors.red;
                        default:
                          return AppColors.primary500; // Egyptian Turquoise
                      }
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary500 : AppColors.neutral200,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: AppColors.primary500.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))]
                            : null,
                      ),
                      child: InkWell(
                        onTap: () => notifier.selectPackage(package),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(getIcon(), color: getIconColor(), size: 28),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      package.nameAr,
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      package.type == 'featured'
                                          ? 'يظهر إعلانك في أعلى نتائج البحث وبطاقة ترويجية ذهبية ملفتة.'
                                          : package.type == 'urgent'
                                              ? 'يضيف شارة "عاجل" حمراء مميزة على إعلانك لجذب مشترين أسرع.'
                                              : 'يرفع إعلانك لأعلى القائمة كأنه نُشر للتو لجذب مشاهدات متجددة.',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${package.price.toStringAsFixed(0)} ج.م',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.primary500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

                const SizedBox(height: 32),

                // 3. FINAL PRICE & CHECKOUT BUTTON
                if (state.selectedPackage != null && state.selectedAd != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary500.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary500.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'إجمالي المبلغ المطلوب دفعه:',
                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              '${state.selectedPackage!.price.toStringAsFixed(0)} ج.م',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.primary500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: state.isVerifying
                                ? null
                                : () async {
                                    final result = await notifier.verifyAndPreparePayment();
                                    if (result != null && context.mounted) {
                                      // Transition to Payment WebView
                                      final success = await context.push<bool?>(
                                        AppRoutes.paymentWebView,
                                        extra: {
                                          'paymentUrl': result['payment_url'],
                                          'transactionId': result['transaction_id'],
                                          'paymentType': 'ad_boost',
                                          'referenceId': state.selectedAd!['id'],
                                        },
                                      );

                                      if (success == true && context.mounted) {
                                        // Refresh eligible list
                                        notifier.fetchUserEligibleAds();
                                        notifier.selectAd(null);
                                        notifier.selectPackage(null);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent500, // Egyptian Gold Accent
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: state.isVerifying
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'أكمل الدفع الآمن مع Paymob',
                                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
