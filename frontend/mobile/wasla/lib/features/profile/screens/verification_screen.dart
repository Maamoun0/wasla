import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/national_id_validator.dart';
import '../providers/verification_controller.dart';

class VerificationScreen extends ConsumerWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verificationControllerProvider);
    final controller = ref.read(verificationControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text(
          'التحقق من الهوية',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: state.isFetchingExisting
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary600),
            )
          : state.existingVerification != null
              ? _buildStatusView(context, state, controller)
              : _buildStepperView(context, ref, state, controller),
    );
  }

  // ── Status View for existing requests (Approved / Pending / Rejected) ──
  Widget _buildStatusView(
    BuildContext context,
    VerificationState state,
    VerificationController controller,
  ) {
    final verification = state.existingVerification!;
    final dbStatus = verification['status'] as String;

    IconData icon;
    Color color;
    String title;
    String description;
    bool showRetryButton = false;

    if (dbStatus == 'approved') {
      icon = Icons.verified_rounded;
      color = AppColors.primary600;
      title = 'تم توثيق الحساب بنجاح';
      description =
          'تهانينا! هويتك موثقة بالكامل الآن. تظهر شارة التوثيق الخضراء بجانب اسمك وإعلاناتك لتعزيز مصداقيتك بين المشترين.';
    } else if (dbStatus == 'rejected') {
      icon = Icons.gpp_bad_rounded;
      color = AppColors.error;
      title = 'تم رفض طلب التوثيق';
      final notes = verification['rejection_reason'] ?? 'المستندات المرسلة غير واضحة أو لا تطابق البيانات الشخصية.';
      description = 'سبب الرفض: $notes\n\nيرجى إعادة المحاولة والتقاط صور أكثر وضوحاً في إضاءة جيدة.';
      showRetryButton = true;
    } else {
      // pending
      icon = Icons.gpp_maybe_rounded;
      color = AppColors.warning;
      title = 'طلبك قيد المراجعة حالياً';
      description =
          'لقد استلمنا مستنداتك بنجاح! يقوم فريق المراجعة بمطابقة الصور وبيانات بطاقتك القومية حالياً. سيتم تحديث حالة حسابك خلال 24 إلى 48 ساعة.';
    }

    return Padding(
      padding: const EdgeInsets.all(AppSizes.xxl),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 80, color: color),
            ),
            const SizedBox(height: AppSizes.xxl),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral900,
                    fontFamily: 'Cairo',
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.neutral700,
                    fontFamily: 'Cairo',
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            if (showRetryButton) ...[
              const SizedBox(height: AppSizes.xxxl),
              ElevatedButton.icon(
                onPressed: () => controller.resetWizard(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'تقديم طلب جديد',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary600,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(200, 50),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Stepper Wizard View ──
  Widget _buildStepperView(
    BuildContext context,
    WidgetRef ref,
    VerificationState state,
    VerificationController controller,
  ) {
    return Stack(
      children: [
        Column(
          children: [
            // Header Progress Indicator
            _buildProgressIndicator(context, state.currentStep),
            
            // Warning Alert Banner
            _buildWarningBanner(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.sm),
                child: _buildStepContent(context, state, controller),
              ),
            ),

            // Bottom Navigation Actions
            _buildBottomActionBar(context, ref, state, controller),
          ],
        ),

        // Loading Overlay during submission
        if (state.status == VerificationStatus.loading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary600),
                      const SizedBox(height: AppSizes.lg),
                      Text(
                        'جاري رفع المستندات وتأكيد الطلب...',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Stepper Steps Content Router ──
  Widget _buildStepContent(
    BuildContext context,
    VerificationState state,
    VerificationController controller,
  ) {
    switch (state.currentStep) {
      case 0:
        return _buildPersonalDataStep(context, state, controller);
      case 1:
        return _buildCaptureCard(
          context: context,
          title: 'صورة وجه البطاقة الشخصية',
          subtitle: 'يرجى تصوير الجهة الأمامية التي تحتوي على الصورة الشخصية والاسم بوضوح تام.',
          file: state.frontIdFile,
          placeholderIcon: Icons.badge_outlined,
          onCapture: () => controller.captureImage(1),
          onClear: () => controller.clearImage(1),
        );
      case 2:
        return _buildCaptureCard(
          context: context,
          title: 'صورة ظهر البطاقة الشخصية',
          subtitle: 'يرجى تصوير الجهة الخلفية التي تحتوي على المسمى الوظيفي والعنوان بوضوح.',
          file: state.backIdFile,
          placeholderIcon: Icons.chrome_reader_mode_outlined,
          onCapture: () => controller.captureImage(2),
          onClear: () => controller.clearImage(2),
        );
      case 3:
        return _buildReviewStep(context, state);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Personal Data Step Form ──
  Widget _buildPersonalDataStep(
    BuildContext context,
    VerificationState state,
    VerificationController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSizes.sm),
        Text(
          'البيانات الشخصية',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.neutral900,
                fontFamily: 'Cairo',
              ),
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          'يرجى إدخال اسمك الكامل ورقمك القومي المكون من 14 رقماً كما هو مدون بالبطاقة الشخصية.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.neutral600,
                fontFamily: 'Cairo',
                height: 1.4,
              ),
        ),
        const SizedBox(height: AppSizes.xl),
        TextFormField(
          initialValue: state.fullName,
          onChanged: controller.setFullName,
          decoration: const InputDecoration(
            labelText: 'الاسم الكامل باللغة العربية',
            hintText: 'مثال: محمد أحمد علي',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline_rounded),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        const SizedBox(height: AppSizes.lg),
        TextFormField(
          initialValue: state.nationalId,
          onChanged: controller.setNationalId,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'الرقم القومي (14 رقماً)',
            hintText: '29505280101234',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.badge_outlined),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
      ],
    );
  }

  // ── Capture Card Component ──
  Widget _buildCaptureCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required File? file,
    required IconData placeholderIcon,
    required VoidCallback onCapture,
    required VoidCallback onClear,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        side: const BorderSide(color: AppColors.neutral200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutral900,
                    fontFamily: 'Cairo',
                  ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.neutral600,
                    fontFamily: 'Cairo',
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: AppSizes.lg),
            AspectRatio(
              aspectRatio: 1.58, // Card ratio (standard ID shape)
              child: file != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(file, fit: BoxFit.cover),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(Icons.delete_rounded, color: Colors.white),
                                onPressed: onClear,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        border: Border.all(
                          color: AppColors.neutral300,
                          style: BorderStyle.solid,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(placeholderIcon, size: 56, color: AppColors.neutral400),
                          const SizedBox(height: AppSizes.md),
                          ElevatedButton.icon(
                            onPressed: onCapture,
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text(
                              'التقط الآن',
                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(180, 48),
                              backgroundColor: AppColors.primary600,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Review step component ──
  Widget _buildReviewStep(BuildContext context, VerificationState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSizes.sm),
        Text(
          'مراجعة وتأكيد طلب التوثيق',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.neutral900,
                fontFamily: 'Cairo',
              ),
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          'يرجى التأكد من صحة البيانات ووضوح الصور المرفقة قبل إرسال الطلب.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.neutral600,
                fontFamily: 'Cairo',
              ),
        ),
        const SizedBox(height: AppSizes.lg),
        
        // Personal Data Card
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: AppSizes.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.neutral200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'البيانات الشخصية',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                ),
                const Divider(),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.neutral500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الاسم: ${state.fullName}',
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 20, color: AppColors.neutral500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الرقم القومي: ${state.nationalId}',
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _buildReviewThumbnail(context, 'وجه البطاقة', state.frontIdFile),
        _buildReviewThumbnail(context, 'ظهر البطاقة', state.backIdFile),
      ],
    );
  }

  Widget _buildReviewThumbnail(BuildContext context, String label, File? file) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.neutral200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 54,
                  child: file != null 
                      ? Image.file(file, fit: BoxFit.cover)
                      : Container(color: AppColors.neutral200),
                ),
              ),
              const SizedBox(width: AppSizes.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'جاهز للرفع',
                      style: TextStyle(color: AppColors.success, fontSize: 12, fontFamily: 'Cairo'),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle_rounded, color: AppColors.success),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress indicator bar at the top ──
  Widget _buildProgressIndicator(BuildContext context, int currentStep) {
    final steps = ['البيانات', 'وجه البطاقة', 'ظهر البطاقة', 'المراجعة'];
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md, horizontal: AppSizes.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(steps.length, (index) {
          final isCompleted = index < currentStep;
          final isCurrent = index == currentStep;
          final color = isCompleted
              ? AppColors.primary600
              : isCurrent
                  ? AppColors.accent500
                  : AppColors.neutral300;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.primary600 : AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: AppColors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[index],
                style: TextStyle(
                  color: isCurrent ? AppColors.neutral900 : AppColors.neutral500,
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Anti-Spoofing Warning Banner ──
  Widget _buildWarningBanner() {
    return Container(
      color: AppColors.warningBg,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.md),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security_rounded, color: AppColors.warning, size: 24),
          SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سياسة منع التزييف والتحايل',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                    fontSize: 13,
                    fontFamily: 'Cairo',
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'يتم التقاط صور المستندات والتحقق عبر الكاميرا الحية فقط. تم تعطيل خيار استيراد الملفات أو الصور من الاستوديو لضمان أمان المعاملات.',
                  style: TextStyle(
                    color: AppColors.neutral800,
                    fontSize: 11,
                    height: 1.4,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Action Navigation Bar ──
  Widget _buildBottomActionBar(
    BuildContext context,
    WidgetRef ref,
    VerificationState state,
    VerificationController controller,
  ) {
    final currentStep = state.currentStep;
    final isLastStep = currentStep == 3;

    // Check if the current step has a valid file/input captured
    bool canProceed = false;
    if (currentStep == 0) {
      canProceed = state.fullName.trim().isNotEmpty && 
                   state.nationalId.trim().isNotEmpty &&
                   NationalIdValidator.validate(state.nationalId) == null;
    } else if (currentStep == 1) {
      canProceed = state.frontIdFile != null;
    } else if (currentStep == 2) {
      canProceed = state.backIdFile != null;
    } else if (currentStep == 3) {
      canProceed = true;
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.neutral200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.md),
      child: Row(
        children: [
          if (currentStep > 0)
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSizes.md),
                child: OutlinedButton(
                  onPressed: () => controller.setStep(currentStep - 1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'السابق',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canProceed
                  ? () {
                      if (isLastStep) {
                        final messenger = ScaffoldMessenger.of(context);
                        controller.submitVerification().then((_) {
                          final latestState = ref.read(verificationControllerProvider);
                          if (latestState.status == VerificationStatus.error) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  latestState.errorMessage ?? 'حدث خطأ ما',
                                  style: const TextStyle(fontFamily: 'Cairo'),
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          } else if (latestState.status == VerificationStatus.success) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تم تقديم طلب التحقق بنجاح.',
                                  style: TextStyle(fontFamily: 'Cairo'),
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        });
                      } else {
                        controller.setStep(currentStep + 1);
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                isLastStep ? 'إرسال طلب التوثيق' : 'التالي',
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
