import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../providers/post_ad_wizard_provider.dart';
import '../models/draft_ad.dart';

class AddPhotosScreen extends ConsumerStatefulWidget {
  const AddPhotosScreen({super.key});

  @override
  ConsumerState<AddPhotosScreen> createState() => _AddPhotosScreenState();
}

class _AddPhotosScreenState extends ConsumerState<AddPhotosScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final state = ref.read(postAdWizardProvider);
    if (state.draft.images.length >= 8) {
      _showErrorSnackBar('لا يمكن إضافة أكثر من 8 صور للإعلان.');
      return;
    }

    try {
      if (source == ImageSource.gallery) {
        final List<XFile> pickedFiles = await _picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1600,
          maxHeight: 1600,
        );
        
        if (pickedFiles.isNotEmpty) {
          int remainingSlots = 8 - state.draft.images.length;
          int filesToAdd = pickedFiles.length > remainingSlots ? remainingSlots : pickedFiles.length;
          
          for (int i = 0; i < filesToAdd; i++) {
            final file = File(pickedFiles[i].path);
            final length = await file.length();
            if (length <= 1024 * 1024 * 5) {
              ref.read(postAdWizardProvider.notifier).addImage(file);
            }
          }
          
          if (pickedFiles.length > remainingSlots) {
            _showErrorSnackBar('تمت إضافة $remainingSlots صور فقط للوصول للحد الأقصى (8 صور).');
          }
        }
      } else {
        final XFile? pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1600,
          maxHeight: 1600,
        );

        if (pickedFile != null) {
          final file = File(pickedFile.path);
          final length = await file.length();
          if (length > 1024 * 1024 * 5) {
            _showErrorSnackBar('حجم الصورة كبير جداً، يرجى اختيار صورة أخرى.');
            return;
          }
          ref.read(postAdWizardProvider.notifier).addImage(file);
        }
      }
    } catch (e) {
      _showErrorSnackBar('حدث خطأ أثناء اختيار الصور.');
    }
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary600),
                title: const Text('المعرض (Gallery)', style: TextStyle(fontFamily: 'Cairo')),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary600),
                title: const Text('الكاميرا (Camera)', style: TextStyle(fontFamily: 'Cairo')),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
          textAlign: TextAlign.right,
        ),
        backgroundColor: AppColors.error,
      ),
    );
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
    final images = state.draft.images;

    final canProceed = notifier.isStepValid(WizardStep.photos);

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
          title: const Text('صور الإعلان'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: 3 / 5,
              backgroundColor: AppColors.neutral100,
              color: AppColors.primary600,
              minHeight: 4,
            ),
          ),
          actions: [
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                color: AppColors.primary600.withOpacity(0.05),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primary600, size: 20),
                    SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        'يمكنك إضافة حتى 8 صور. الصورة الأولى ستكون صورة الغلاف الرئيسية. اسحب لإعادة الترتيب.',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.primary700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Photos Area
              Expanded(
                child: images.isEmpty
                    ? _buildEmptyState()
                    : _buildReorderableList(images, notifier),
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
                        onPressed: () {
                          notifier.setStep(WizardStep.details);
                          context.pop();
                        },
                        child: const Text('السابق', style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: canProceed
                            ? () {
                                notifier.setStep(WizardStep.location);
                                context.push(AppRoutes.postLocation);
                              }
                            : null,
                        child: const Text('التالي', style: TextStyle(fontFamily: 'Cairo')),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.neutral100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                size: 64,
                color: AppColors.neutral400,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            const Text(
              'لا توجد صور بعد',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.neutral800,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            const Text(
              'أضف صوراً واضحة لجذب المزيد من المشترين لإعلانك',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: AppColors.neutral500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.lg),
            ElevatedButton.icon(
              onPressed: _showImageSourceBottomSheet,
              icon: const Icon(Icons.add_a_photo_rounded, size: 20),
              label: const Text('إضافة صورة', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderableList(List<DraftImage> images, PostAdWizardNotifier notifier) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الصور المضافة (${images.length}/8)',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.neutral700,
                ),
              ),
              if (images.length < 8)
                TextButton.icon(
                  onPressed: _showImageSourceBottomSheet,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                  label: const Text('إضافة صورة', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: images.length,
            onReorder: notifier.reorderImages,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemBuilder: (ctx, index) {
              final img = images[index];
              return _buildImageTile(img, index, notifier);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageTile(DraftImage img, int index, PostAdWizardNotifier notifier) {
    final isCover = index == 0; // The first in order is visually Cover
    
    return Container(
      key: ValueKey(img.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCover ? AppColors.primary600 : AppColors.neutral200,
          width: isCover ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thumbnail
              Container(
                width: 90,
                height: 90,
                color: AppColors.neutral100,
                child: img.localFile != null
                    ? Image.file(
                        img.localFile!,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image_rounded, color: AppColors.neutral400),
              ),
              
              // Status & Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          if (isCover)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary600.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'صورة الغلاف',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary600,
                                ),
                              ),
                            )
                          else
                            Text(
                              'الصورة رقم ${index + 1}',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: AppColors.neutral600,
                              ),
                            ),
                          const Spacer(),
                          const Icon(Icons.drag_indicator_rounded, color: AppColors.neutral400, size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Progress / Error / Success
                      if (img.isUploading) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: img.uploadProgress,
                                backgroundColor: AppColors.neutral100,
                                color: AppColors.primary600,
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(img.uploadProgress * 100).toInt()}%',
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.neutral600),
                            ),
                          ],
                        ),
                      ] else if (img.uploadError != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 14),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Text(
                                'فشل الرفع',
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.error),
                              ),
                            ),
                            TextButton(
                              onPressed: () => notifier.retryUploadImage(img.id),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'إعادة المحاولة',
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.primary600),
                              ),
                            ),
                          ],
                        ),
                      ] else if (img.remoteUrl != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'تم الرفع بنجاح',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.green.shade700),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Delete button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => notifier.removeImage(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
