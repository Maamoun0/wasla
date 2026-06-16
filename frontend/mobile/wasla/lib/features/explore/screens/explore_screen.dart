import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/providers/ads_provider.dart';
import '../../../shared/widgets/wasla_logo.dart' show AdCard, AdCardShimmer, EmptyState;

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchCtrl   = TextEditingController();
  final _scrollCtrl   = ScrollController();
  bool _isGridView    = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(adsNotifierProvider.notifier).load();
    }
  }

  void _search(String q) {
    ref.read(adsNotifierProvider.notifier).applyFilter(
      AdsFilter(query: q.isNotEmpty ? q : null),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FilterSheet(),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adsState = ref.watch(adsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search Bar ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onSubmitted: _search,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن خدمة، إعلان...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _search('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      onChanged: (v) {
                        setState(() {});
                        if (v.isEmpty) _search('');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Filter button
                  Material(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showFilters,
                      child: Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.neutral200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.tune_rounded, color: AppColors.neutral600),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── View Toggle + Count ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(
                    adsState.isLoading ? 'جاري البحث...' : '${adsState.ads.length} نتيجة',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  _ViewToggle(
                    isGrid: _isGridView,
                    onToggle: (v) => setState(() => _isGridView = v),
                  ),
                ],
              ),
            ),

            // ── Results ──────────────────────────────────────
            Expanded(
              child: adsState.isLoading && adsState.ads.isEmpty
                  ? _buildShimmer()
                  : adsState.ads.isEmpty
                      ? EmptyState(
                          title: AppStrings.noAdsFound,
                          subtitle: AppStrings.noAdsDesc,
                          action: TextButton(
                            onPressed: () => ref.read(adsNotifierProvider.notifier).clearFilters(),
                            child: const Text('مسح الفلاتر'),
                          ),
                        )
                      : _isGridView
                          ? _buildGrid(adsState)
                          : _buildList(adsState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const AdCardShimmer(),
    );
  }

  Widget _buildGrid(AdsState adsState) {
    return GridView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72,
      ),
      itemCount: adsState.ads.length + (adsState.hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == adsState.ads.length) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ));
        }
        return AdCard(ad: adsState.ads[i]);
      },
    );
  }

  Widget _buildList(AdsState adsState) {
    return ListView.separated(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: adsState.ads.length + (adsState.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        if (i == adsState.ads.length) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ));
        }
        return AdCard(ad: adsState.ads[i]);
      },
    );
  }
}

// ── View Toggle ───────────────────────────────────────────────────
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.isGrid, required this.onToggle});
  final bool isGrid;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _ToggleBtn(icon: Icons.grid_view_rounded,    isActive: isGrid,  onTap: () => onToggle(true)),
          _ToggleBtn(icon: Icons.view_list_rounded,    isActive: !isGrid, onTap: () => onToggle(false)),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({required this.icon, required this.isActive, required this.onTap});
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary600 : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 18, color: isActive ? Colors.white : AppColors.neutral500),
      ),
    );
  }
}

// ── Filter Bottom Sheet ───────────────────────────────────────────
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  String? _adType;
  double _minPrice = 0;
  double _maxPrice = 50000;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.neutral200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text('الفلاتر', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),

          // Ad Type
          Text('نوع الإعلان', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              _FilterChip(label: 'الكل',    value: null,        selected: _adType == null,       onTap: () => setState(() => _adType = null)),
              _FilterChip(label: 'معروض',   value: 'offering',  selected: _adType == 'offering', onTap: () => setState(() => _adType = 'offering')),
              _FilterChip(label: 'مطلوب',   value: 'seeking',   selected: _adType == 'seeking',  onTap: () => setState(() => _adType = 'seeking')),
            ],
          ),
          const SizedBox(height: 20),

          // Price Range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('نطاق السعر', style: Theme.of(context).textTheme.titleSmall),
              Text(
                '${_minPrice.toInt()} — ${_maxPrice.toInt()} ج.م',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          RangeSlider(
            values: RangeValues(_minPrice, _maxPrice),
            min: 0, max: 50000,
            divisions: 100,
            activeColor: AppColors.primary600,
            onChanged: (v) => setState(() {
              _minPrice = v.start;
              _maxPrice = v.end;
            }),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() { _adType = null; _minPrice = 0; _maxPrice = 50000; });
                    ref.read(adsNotifierProvider.notifier).clearFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('مسح الكل'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(adsNotifierProvider.notifier).applyFilter(
                      AdsFilter(
                        adType: _adType,
                        minPrice: _minPrice > 0 ? _minPrice : null,
                        maxPrice: _maxPrice < 50000 ? _maxPrice : null,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('تطبيق'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onTap});
  final String label;
  final String? value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary600 : AppColors.neutral100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary600 : AppColors.neutral200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.neutral700,
          ),
        ),
      ),
    );
  }
}
