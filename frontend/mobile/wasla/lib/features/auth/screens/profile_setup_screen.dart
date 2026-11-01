import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/providers/locations_provider.dart';
import '../../../shared/widgets/wasla_logo.dart';
import '../providers/auth_provider.dart';
import '../../../data/repositories/auth_repository.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.returnTo});

  /// The page the user was on before signing in.
  final String? returnTo;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _formKey  = GlobalKey<FormState>();
  String? _avatarUrl;
  int? _governorateId;
  int? _cityId;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    // Keep well under the bucket's 2 MB limit.
    final image  = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1024, maxHeight: 1024);
    if (image == null) return;

    final uid    = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await image.readAsBytes();

      final url = await ref.read(authRepositoryProvider).uploadAvatar(uid, bytes);
      setState(() => _avatarUrl = url);
    } catch (e) {
      _showError('حدث خطأ في رفع الصورة');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).updateProfile(
        fullName: _nameCtrl.text.trim(),
        avatarUrl: _avatarUrl,
        cityId: _cityId,
      );
      if (mounted) context.go(widget.returnTo ?? AppRoutes.home);
    } catch (_) {
      _showError(AppStrings.errorGeneral);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Header
                const Center(child: WaslaLogoFull(size: 36)),
                const SizedBox(height: 32),

                Text('أخبرنا عن نفسك', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('تفاصيل مختصرة تساعد الآخرين على الثقة بك',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.neutral500),
                  textAlign: TextAlign.center),
                const SizedBox(height: 40),

                // ── Avatar Picker ──────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: AppColors.primary50,
                          backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                          child: _avatarUrl == null
                              ? const Icon(Icons.person_rounded, size: 52, color: AppColors.primary200)
                              : null,
                        ),
                        Positioned(
                          bottom: 0, left: 0,
                          child: Container(
                            width: 32, height: 32,
                            decoration: const BoxDecoration(
                              color: AppColors.primary600,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Name Field ─────────────────────────────────
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    hintText: 'مثال: محمد أحمد',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? AppStrings.errorRequired : null,
                ),
                const SizedBox(height: 16),

                // ── City (FR-1.3) ──────────────────────────────
                _CityPicker(
                  governorateId: _governorateId,
                  cityId: _cityId,
                  onGovernorate: (id) => setState(() {
                    _governorateId = id;
                    _cityId = null;
                  }),
                  onCity: (id) => setState(() => _cityId = id),
                ),
                const SizedBox(height: 32),

                // ── Save Button ────────────────────────────────
                PrimaryButton(label: 'ابدأ الاستخدام', onPressed: _save, isLoading: _isLoading),
                const SizedBox(height: 16),

                // Skip
                TextButton(
                  onPressed: () => context.go(widget.returnTo ?? AppRoutes.home),
                  child: const Text('تخطي الآن', style: TextStyle(color: AppColors.neutral400, fontFamily: 'Cairo')),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Governorate, then a city in it. Both required when saving the profile.
class _CityPicker extends ConsumerWidget {
  const _CityPicker({
    required this.governorateId,
    required this.cityId,
    required this.onGovernorate,
    required this.onCity,
  });

  final int? governorateId;
  final int? cityId;
  final ValueChanged<int?> onGovernorate;
  final ValueChanged<int?> onCity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final governorates = ref.watch(governoratesProvider);
    final cities = governorateId == null ? null : ref.watch(citiesProvider(governorateId!));

    List<DropdownMenuItem<int>> items(List<Map<String, dynamic>> rows) => [
          for (final r in rows) DropdownMenuItem(value: r['id'] as int, child: Text(r['name_ar'] as String? ?? '')),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('gov:$governorateId'),
          initialValue: governorateId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'المحافظة',
            prefixIcon: Icon(Icons.map_outlined),
          ),
          items: items(governorates.valueOrNull ?? const []),
          onChanged: governorates.hasValue ? onGovernorate : null,
          validator: (v) => v == null ? AppStrings.errorRequired : null,
        ),
        if (governorates.hasError)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('تعذّر تحميل المحافظات', style: TextStyle(color: AppColors.error, fontFamily: 'Cairo')),
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: ValueKey('city:$governorateId:$cityId'),
          initialValue: cityId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'المدينة / الحي',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          items: items(cities?.valueOrNull ?? const []),
          onChanged: (cities?.hasValue ?? false) ? onCity : null,
          validator: (v) => v == null ? AppStrings.errorRequired : null,
        ),
      ],
    );
  }
}
