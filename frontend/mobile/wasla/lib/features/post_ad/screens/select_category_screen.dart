import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/providers/ads_provider.dart';

// ── Post Ad Draft State ────────────────────────────────────────────
class PostAdDraft {
  final int? categoryId;
  final String? categoryNameAr;
  final String? adType;
  final String? title;
  final String? description;
  final double? price;
  final String priceType;
  final int? cityId;
  final int? districtId;
  final double? latitude;
  final double? longitude;
  final List<String> photoUrls;
  final Map<String, dynamic> dynamicFields;

  const PostAdDraft({
    this.categoryId,
    this.categoryNameAr,
    this.adType = 'offering',
    this.title,
    this.description,
    this.price,
    this.priceType = 'fixed',
    this.cityId,
    this.districtId,
    this.latitude,
    this.longitude,
    this.photoUrls = const [],
    this.dynamicFields = const {},
  });

  PostAdDraft copyWith({
    int? categoryId, String? categoryNameAr, String? adType,
    String? title, String? description, double? price, String? priceType,
    int? cityId, int? districtId, double? latitude, double? longitude,
    List<String>? photoUrls, Map<String, dynamic>? dynamicFields,
  }) => PostAdDraft(
    categoryId:    categoryId    ?? this.categoryId,
    categoryNameAr:categoryNameAr?? this.categoryNameAr,
    adType:        adType        ?? this.adType,
    title:         title         ?? this.title,
    description:   description   ?? this.description,
    price:         price         ?? this.price,
    priceType:     priceType     ?? this.priceType,
    cityId:        cityId        ?? this.cityId,
    districtId:    districtId    ?? this.districtId,
    latitude:      latitude      ?? this.latitude,
    longitude:     longitude     ?? this.longitude,
    photoUrls:     photoUrls     ?? this.photoUrls,
    dynamicFields: dynamicFields ?? this.dynamicFields,
  );
}

final postAdDraftProvider = StateProvider<PostAdDraft>((ref) => const PostAdDraft());

// ── Select Category Screen ─────────────────────────────────────────
class SelectCategoryScreen extends ConsumerStatefulWidget {
  const SelectCategoryScreen({super.key});

  @override
  ConsumerState<SelectCategoryScreen> createState() => _SelectCategoryScreenState();
}

class _SelectCategoryScreenState extends ConsumerState<SelectCategoryScreen> {
  Map<String, dynamic>? _selectedMain;

  static const _catColors = {
    'services':    (bg: Color(0xFFE0F2FE), fg: Color(0xFF0369A1)),
    'jobs':        (bg: Color(0xFFEDE9FE), fg: Color(0xFF5B21B6)),
    'real-estate': (bg: Color(0xFFDCFCE7), fg: Color(0xFF15803D)),
    'vehicles':    (bg: Color(0xFFFEF9C3), fg: Color(0xFF854D0E)),
    'goods':       (bg: Color(0xFFFEE2E2), fg: Color(0xFFB91C1C)),
  };

  @override
  Widget build(BuildContext context) {
    final categories    = ref.watch(categoriesProvider);
    final subCategories = _selectedMain != null
        ? ref.watch(subCategoriesProvider(_selectedMain!['id'] as int))
        : null;

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text(AppStrings.selectCategory),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _ProgressBar(step: 1, total: 5),
        ),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (cats) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                _selectedMain == null ? 'اختر القسم الرئيسي' : 'اختر القسم الفرعي',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),

            if (_selectedMain != null) ...[
              // Back to main
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMain = null),
                  child: Row(children: [
                    const Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppColors.primary600),
                    Text(_selectedMain!['name_ar'] as String, style: const TextStyle(
                      fontFamily: 'Cairo', color: AppColors.primary600, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ],

            Expanded(
              child: _selectedMain == null
                  ? _MainCategoriesGrid(cats: cats, colors: _catColors,
                      onSelect: (cat) => setState(() => _selectedMain = cat))
                  : subCategories == null ? const SizedBox()
                  : subCategories.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox(),
                      data: (subs) => _SubCategoriesList(
                        subs: subs,
                        mainCat: _selectedMain!,
                        colors: _catColors,
                        onSelect: (sub) {
                          ref.read(postAdDraftProvider.notifier).state =
                              ref.read(postAdDraftProvider).copyWith(
                                categoryId: sub['id'] as int,
                                categoryNameAr: sub['name_ar'] as String?,
                              );
                          context.push(AppRoutes.postForm);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step, required this.total});
  final int step, total;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: step / total,
      backgroundColor: AppColors.neutral100,
      color: AppColors.primary600,
      minHeight: 4,
    );
  }
}

class _MainCategoriesGrid extends StatelessWidget {
  const _MainCategoriesGrid({required this.cats, required this.colors, required this.onSelect});
  final List<Map<String, dynamic>> cats;
  final Map<String, ({Color bg, Color fg})> colors;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.3,
        ),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final cat   = cats[i];
          final slug  = cat['slug'] as String? ?? '';
          final style = colors[slug] ?? (bg: AppColors.neutral100, fg: AppColors.neutral600);

          return GestureDetector(
            onTap: () => onSelect(cat),
            child: Container(
              decoration: BoxDecoration(
                color: style.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: style.fg.withOpacity(0.2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(cat['icon'] as String? ?? '📦', style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 8),
                  Text(cat['name_ar'] as String? ?? '',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700, color: style.fg)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SubCategoriesList extends StatelessWidget {
  const _SubCategoriesList({required this.subs, required this.mainCat, required this.colors, required this.onSelect});
  final List<Map<String, dynamic>> subs;
  final Map<String, dynamic> mainCat;
  final Map<String, ({Color bg, Color fg})> colors;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    final slug  = mainCat['slug'] as String? ?? '';
    final style = colors[slug] ?? (bg: AppColors.neutral100, fg: AppColors.neutral600);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: subs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final sub = subs[i];
        return GestureDetector(
          onTap: () => onSelect(sub),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Row(children: [
              Text(sub['icon'] as String? ?? '📦', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(child: Text(sub['name_ar'] as String? ?? '',
                style: Theme.of(context).textTheme.titleMedium)),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: style.fg),
            ]),
          ),
        );
      },
    );
  }
}
