import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../providers/post_ad_wizard_provider.dart';
import '../models/draft_ad.dart';
import '../../../shared/widgets/trust_badge.dart';
import '../../../features/auth/providers/auth_provider.dart';

class AdPreviewScreen extends ConsumerStatefulWidget {
  const AdPreviewScreen({super.key});

  @override
  ConsumerState<AdPreviewScreen> createState() => _AdPreviewScreenState();
}

class _AdPreviewScreenState extends ConsumerState<AdPreviewScreen> {
  final _pageController = PageController();
  int _currentPhoto = 0;
  bool _descExpanded = false;

  void _editStep(WizardStep step, String route) {
    ref.read(postAdWizardProvider.notifier).setStep(step);
    context.go(route);
  }

  Future<void> _publish() async {
    final notifier = ref.read(postAdWizardProvider.notifier);
    try {
      final adId = await notifier.publishAd();
      if (adId != null && mounted) {
        // Navigate to success screen with created ad ID
        context.go('${AppRoutes.postSuccess}?id=$adId');
      }
    } catch (e) {
      // Error handled by state.errorMessage in UI
    }
  }

  // Confirm wizard exit
  Future<bool> _showExitConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('هل أنت متأكد من الخروج؟', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text(
          'سيؤدي الخروج إلى حذف كافة البيانات التي قمت بإدخالها في مسودة الإعلان الحالية.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.neutral600)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(postAdWizardProvider.notifier).reset();
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('خروج ومسح', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postAdWizardProvider);
    final notifier = ref.read(postAdWizardProvider.notifier);
    final draft = state.draft;
    
    final userProfileAsync = ref.watch(currentUserProvider);

    final uploadedImages = draft.images.where((img) => img.remoteUrl != null).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (state.isSubmitting) return; // Prevent back press while submitting
        final shouldPop = await _showExitConfirmation(context);
        if (shouldPop && context.mounted) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        appBar: AppBar(
          title: const Text('معاينة الإعلان'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: 5 / 5,
              backgroundColor: AppColors.neutral100,
              color: AppColors.primary600,
              minHeight: 4,
            ),
          ),
          actions: [
            if (!state.isSubmitting)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () async {
                  final shouldPop = await _showExitConfirmation(context);
                  if (shouldPop && context.mounted) {
                    context.go(AppRoutes.home);
                  }
                },
              ),
          ],
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // Error Banner
              if (state.errorMessage != null)
                Container(
                  color: AppColors.error.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.error, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── 1. PHOTOS SECTION (With Edit Button Overlay) ──
                      Stack(
                        children: [
                          Container(
                            height: 260,
                            color: AppColors.neutral900,
                            child: uploadedImages.isEmpty
                                ? const Center(
                                    child: Icon(Icons.image_outlined, size: 80, color: AppColors.neutral400),
                                  )
                                : PageView.builder(
                                    controller: _pageController,
                                    itemCount: uploadedImages.length,
                                    onPageChanged: (i) => setState(() => _currentPhoto = i),
                                    itemBuilder: (_, i) => CachedNetworkImage(
                                      imageUrl: uploadedImages[i].remoteUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: AppColors.neutral200),
                                      errorWidget: (_, __, ___) => Container(color: AppColors.neutral200, child: const Icon(Icons.broken_image)),
                                    ),
                                  ),
                          ),
                          if (uploadedImages.length > 1)
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  uploadedImages.length,
                                  (i) => AnimatedContainer(
                                    duration: AppDurations.fast,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: i == _currentPhoto ? 20 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: i == _currentPhoto ? AppColors.white : AppColors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Edit overlay button
                          if (!state.isSubmitting)
                            Positioned(
                              top: 12,
                              left: 16,
                              child: _EditStepBtn(
                                onTap: () => _editStep(WizardStep.photos, AppRoutes.postPhotos),
                              ),
                            ),
                        ],
                      ),

                      Padding(
                        padding: const EdgeInsets.all(AppSizes.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── 2. TITLE & PRICE (With Edit Button) ──
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    draft.title.isNotEmpty ? draft.title : 'عنوان الإعلان سيظهر هنا',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.neutral900,
                                    ),
                                  ),
                                ),
                                if (!state.isSubmitting)
                                  _EditStepBtn(
                                    onTap: () => _editStep(WizardStep.details, AppRoutes.postForm),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildPriceRow(draft),
                            const SizedBox(height: 12),

                            // Location & Date
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 16, color: AppColors.neutral400),
                                const SizedBox(width: 4),
                                Text(
                                  [
                                    draft.cityNameAr ?? 'المدينة',
                                    if (draft.districtNameAr != null && draft.districtNameAr!.isNotEmpty)
                                      draft.districtNameAr
                                  ].join(' — '),
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.neutral600),
                                ),
                                const Spacer(),
                                if (!state.isSubmitting)
                                  _EditStepBtn(
                                    onTap: () => _editStep(WizardStep.location, AppRoutes.postLocation),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: AppColors.neutral200),

                            // ── 3. DYNAMIC FIELDS ──
                            if (draft.dynamicFieldValues.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildDynamicFieldsGrid(draft.dynamicFieldValues),
                              const SizedBox(height: 16),
                              const Divider(color: AppColors.neutral200),
                            ],

                            // ── 4. DESCRIPTION ──
                            const SizedBox(height: 8),
                            const Text(
                              'التفاصيل',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.neutral800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => setState(() => _descExpanded = !_descExpanded),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    draft.description.isNotEmpty ? draft.description : 'تفاصيل الإعلان...',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 14,
                                      color: AppColors.neutral700,
                                      height: 1.5,
                                    ),
                                    maxLines: _descExpanded ? null : 4,
                                    overflow: _descExpanded ? null : TextOverflow.ellipsis,
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() => _descExpanded = !_descExpanded),
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                    child: Text(
                                      _descExpanded ? 'عرض أقل' : 'عرض المزيد',
                                      style: const TextStyle(fontFamily: 'Cairo'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Divider(color: AppColors.neutral200),

                            // ── 5. SELLER CARD ──
                            const SizedBox(height: 8),
                            userProfileAsync.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, _) => const SizedBox.shrink(),
                              data: (profile) {
                                if (profile == null) return const SizedBox.shrink();
                                return _buildSellerCard(profile);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Button Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.md),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(top: BorderSide(color: AppColors.neutral200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: state.isSubmitting
                            ? null
                            : () {
                                notifier.setStep(WizardStep.location);
                                context.pop();
                              },
                        child: const Text('السابق', style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: state.isSubmitting ? null : _publish,
                        child: state.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                state.errorMessage != null ? 'إعادة المحاولة' : 'انشر الإعلان الآن',
                                style: const TextStyle(fontFamily: 'Cairo'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(DraftAd draft) {
    final priceType = draft.priceType;
    final price = draft.price;
    final adType = draft.adType;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: adType == 'offering' ? AppColors.primary50 : AppColors.accent50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            adType == 'offering' ? AppStrings.offering : AppStrings.seeking,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: adType == 'offering' ? AppColors.primary600 : AppColors.accent600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (priceType == PriceType.free)
          const Text('مجانًا', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 22, color: AppColors.success))
        else if (priceType == PriceType.negotiable || price == null)
          const Text('قابل للتفاوض', style: TextStyle(fontFamily: 'Cairo', color: AppColors.neutral500))
        else
          RichText(
            text: TextSpan(
              style: const TextStyle(fontFamily: 'Cairo'),
              children: [
                TextSpan(
                  text: '${price.toInt()} ',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary600),
                ),
                const TextSpan(
                  text: 'ج.م',
                  style: TextStyle(fontSize: 13, color: AppColors.neutral500),
                ),
                if (priceType == PriceType.perHour)
                  const TextSpan(text: ' / ساعة', style: TextStyle(fontSize: 13, color: AppColors.neutral500)),
                if (priceType == PriceType.perMonth)
                  const TextSpan(text: ' / شهر', style: TextStyle(fontSize: 13, color: AppColors.neutral500)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDynamicFieldsGrid(Map<String, dynamic> fields) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: fields.entries.map((e) {
        final label = e.key;
        final value = e.value;
        if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
        
        String displayValue = value.toString();
        if (value is bool) {
          displayValue = value ? 'نعم' : 'لا';
        } else if (value is Map && value.containsKey('min') && value.containsKey('max')) {
          displayValue = '${value['min']} - ${value['max']}';
        } else if (value is List) {
          displayValue = value.join(', ');
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.neutral500)),
              const SizedBox(height: 2),
              Text(displayValue, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.neutral800)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSellerCard(Map<String, dynamic> user) {
    final name = user['full_name'] as String? ?? 'مستخدم وصلة';
    final avatar = user['avatar_url'] as String?;
    final score = (user['trust_score'] as num?)?.toDouble() ?? 5.0;
    final isVerified = user['is_id_verified'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary50,
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null ? const Icon(Icons.person_rounded, color: AppColors.primary200, size: 26) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                TrustBadge(trustScore: score, isVerified: isVerified),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditStepBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _EditStepBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.edit_rounded, color: AppColors.primary600, size: 14),
            SizedBox(width: 4),
            Text(
              'تعديل',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
