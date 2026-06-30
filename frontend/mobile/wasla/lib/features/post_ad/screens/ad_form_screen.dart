import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../providers/post_ad_wizard_provider.dart';
import '../providers/category_fields_provider.dart';
import '../widgets/dynamic_field_builder.dart';
import '../models/draft_ad.dart';

class AdFormScreen extends ConsumerStatefulWidget {
  const AdFormScreen({super.key});

  @override
  ConsumerState<AdFormScreen> createState() => _AdFormScreenState();
}

class _AdFormScreenState extends ConsumerState<AdFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(postAdWizardProvider).draft;
    _titleController = TextEditingController(text: draft.title);
    _descController = TextEditingController(text: draft.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
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
    final categoryId = state.draft.categoryId;

    // Guard in case category is not selected
    if (categoryId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppRoutes.postCategory);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final fieldsAsync = ref.watch(categoryFieldsProvider(categoryId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation(context);
        if (shouldPop && context.mounted) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        appBar: AppBar(
          title: Text(AppStrings.adDetails),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: 2 / 5,
              backgroundColor: AppColors.neutral100,
              color: AppColors.primary600,
              minHeight: 4,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final shouldPop = await _showExitConfirmation(context);
              if (shouldPop && context.mounted) {
                context.go(AppRoutes.home);
              }
            },
          ),
        ),
        body: fieldsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary600),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                const SizedBox(height: AppSizes.md),
                Text('فشل تحميل حقول القسم: $err', style: const TextStyle(fontFamily: 'Cairo')),
                TextButton(
                  onPressed: () => ref.refresh(categoryFieldsProvider(categoryId)),
                  child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
          ),
          data: (fields) {
            // Find required field names/IDs to run isStepValid
            final requiredFields = fields
                .where((f) => f['is_required'] == true)
                .map((f) => f['field_name'] as String)
                .toList();

            final isValid = notifier.isStepValid(WizardStep.details, requiredDynamicFieldIds: requiredFields);

            return Column(
              children: [
                // Category Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.md),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: Border(bottom: BorderSide(color: AppColors.neutral200)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open_rounded, color: AppColors.primary600, size: 20),
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        'القسم المختار: ${state.draft.categoryNameAr ?? 'عام'}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutral700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.postCategory),
                        child: const Text('تغيير القسم', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                // Main Form
                Expanded(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSizes.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Title Input ──
                          const Text(
                            'عنوان الإعلان',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral800,
                            ),
                          ),
                          const SizedBox(height: AppSizes.sm),
                          TextFormField(
                            controller: _titleController,
                            onChanged: (val) {
                              notifier.setTitle(val);
                              setState(() {}); // Trigger step valid check
                            },
                            maxLength: 80,
                            decoration: const InputDecoration(
                              hintText: 'مثال: شقة للبيع في مدينة نصر تشطيب سوبر لوكس',
                              counterText: '',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'عنوان الإعلان مطلوب';
                              if (val.trim().length < 10) return 'يجب ألا يقل العنوان عن 10 أحرف';
                              if (val.trim().length > 80) return 'يجب ألا يزيد العنوان عن 80 حرفاً';
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.md),

                          // ── Description Input ──
                          const Text(
                            'وصف التفاصيل',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral800,
                            ),
                          ),
                          const SizedBox(height: AppSizes.sm),
                          TextFormField(
                            controller: _descController,
                            onChanged: (val) {
                              notifier.setDescription(val);
                              setState(() {}); // Trigger step valid check
                            },
                            maxLines: 5,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              hintText: 'اكتب مواصفات وتفاصيل إعلانك بالتفصيل هنا...',
                              counterText: '',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'الوصف التفصيلي مطلوب';
                              if (val.trim().length < 20) return 'يجب ألا يقل الوصف عن 20 حرفاً';
                              if (val.trim().length > 1000) return 'يجب ألا يزيد الوصف عن 1000 حرف';
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.lg),

                          // ── Dynamic Fields Divider ──
                          if (fields.isNotEmpty) ...[
                            const Divider(height: AppSizes.xxl, color: AppColors.neutral200),
                            const Text(
                              'تفاصيل القسم الإضافية',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary700,
                              ),
                            ),
                            const SizedBox(height: AppSizes.md),
                          ],

                          // ── Dynamic Fields List ──
                          ...fields.map((field) {
                            final fieldName = field['field_name'] as String;
                            return DynamicFieldBuilder(
                              field: field,
                              currentValue: state.draft.dynamicFieldValues[fieldName],
                              onChanged: (val) {
                                notifier.updateField(fieldName, val);
                                setState(() {}); // Trigger step valid check
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer Navigation
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
                          onPressed: () => context.go(AppRoutes.postCategory),
                          child: const Text('السابق', style: TextStyle(fontFamily: 'Cairo')),
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isValid && (_formKey.currentState?.validate() ?? false)
                              ? () {
                                  notifier.setStep(WizardStep.photos);
                                  // Navigate to next screen (sprint 2 placeholder)
                                  context.push(AppRoutes.postPhotos);
                                }
                              : null,
                          child: const Text('التالي', style: TextStyle(fontFamily: 'Cairo')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
