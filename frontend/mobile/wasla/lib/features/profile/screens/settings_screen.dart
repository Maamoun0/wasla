import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:easy_localization/easy_localization.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = false;

  Future<void> _showDeleteConfirmationDialog() async {
    final reasonController = TextEditingController();
    bool dialogSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: !_isLoading,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Directionality(
              textDirection: Directionality.of(context),
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'تأكيد حذف الحساب',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.neutral900,
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'عند حذف حسابك، سيتم تسجيل خروجك وجدولة بياناتك للحذف النهائي خلال 30 يوماً. هل أنت متأكد من رغبتك في الاستمرار؟',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: AppColors.neutral700,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ما هو سبب رغبتك في حذف الحساب؟ (اختياري)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.neutral600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'اكتب سبب مغادرتك هنا...',
                          hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.neutral400),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.neutral300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.error),
                          ),
                        ),
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: dialogSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(fontFamily: 'Cairo', color: AppColors.neutral600, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: dialogSubmitting
                        ? null
                        : () async {
                            setStateDialog(() {
                              dialogSubmitting = true;
                            });
                            setState(() {
                              _isLoading = true;
                            });

                            final navigator = Navigator.of(ctx);
                            final scaffoldMessenger = ScaffoldMessenger.of(ctx);

                            try {
                              final client = ref.read(supabaseClientProvider);
                              final userId = ref.read(currentUserIdProvider);
                              final reason = reasonController.text.trim();

                              if (userId != null) {
                                // Hides the account and its ads now, blocks sign-in,
                                // and schedules the permanent purge 30 days later.
                                await client.rpc('request_account_deletion', params: {
                                  'p_reason': reason.isNotEmpty ? reason : null,
                                });

                                if (ctx.mounted) {
                                  navigator.pop();
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'تم تسجيل طلب حذف الحساب بنجاح وسيتم تسجيل خروجك الآن.',
                                        style: TextStyle(fontFamily: 'Cairo'),
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }

                                // Sign out
                                await ref.read(authNotifierProvider.notifier).signOut();
                              }
                            } catch (e) {
                              setStateDialog(() {
                                dialogSubmitting = false;
                              });
                              setState(() {
                                _isLoading = false;
                              });
                              if (ctx.mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'حدث خطأ أثناء إرسال الطلب: $e',
                                      style: const TextStyle(fontFamily: 'Cairo'),
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: dialogSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'تأكيد الحذف',
                            style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: Directionality.of(context),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary600,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // App preferences category
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'تفضيلات التطبيق',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.neutral500,
                      ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.neutral200),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined, color: AppColors.primary600),
                          title: const Text('الإشعارات', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.neutral400),
                          onTap: () => context.push(AppRoutes.notificationSettings),
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.neutral200),
                        ListTile(
                          leading: const Icon(Icons.language_rounded, color: AppColors.primary600),
                          title: Text('language'.tr(), style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                          subtitle: Text(context.locale.languageCode == 'ar' ? 'العربية' : 'English', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.neutral500)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.neutral400),
                          onTap: () {
                            if (context.locale.languageCode == 'ar') {
                              context.setLocale(const Locale('en', 'US'));
                            } else {
                              context.setLocale(const Locale('ar', 'EG'));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Legal & Support category
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'الدعم والشروط القانونية',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.neutral500,
                      ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.neutral200),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary600),
                          title: const Text('سياسة الخصوصية', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.neutral400),
                          onTap: () => context.push('/legal/privacy'),
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.neutral200),
                        ListTile(
                          leading: const Icon(Icons.description_outlined, color: AppColors.primary600),
                          title: const Text('شروط الاستخدام', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.neutral400),
                          onTap: () => context.push('/legal/terms'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Danger zone category
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'منطقة الخطر',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.errorBg),
                    ),
                    color: AppColors.errorBg.withValues(alpha: 0.5),
                    child: ListTile(
                      leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                      title: const Text(
                        'حذف الحساب',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                      subtitle: const Text(
                        'حذف جميع بياناتك وحسابك نهائياً من منصة Wasla',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.neutral500),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.error),
                      onTap: _showDeleteConfirmationDialog,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
