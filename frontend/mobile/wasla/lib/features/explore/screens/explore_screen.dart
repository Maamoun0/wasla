import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/providers/ads_provider.dart';
import '../../../shared/providers/locations_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../saved/providers/saved_searches_provider.dart';
import '../../../shared/widgets/wasla_logo.dart' show AdCard, AdCardShimmer, EmptyState;
import '../map/ads_map.dart';
import '../../../data/repositories/saved_repository.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key, this.initialFilter});

  /// The search the URL asks for (/explore?category=…); null keeps the open one.
  final AdsFilter? initialFilter;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchCtrl   = TextEditingController();
  final _scrollCtrl   = ScrollController();
  _ResultsView _view  = _ResultsView.grid;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    // Explore can be opened with a search already applied (a saved search).
    _searchCtrl.text = ref.read(adsNotifierProvider).filter.query ?? '';
    Future.microtask(() => _applyUrlFilter(firstOpen: true));
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Same page, new URL (deep link, back to an earlier search).
    if (widget.initialFilter != null) Future.microtask(_applyUrlFilter);
  }

  void _applyUrlFilter({bool firstOpen = false}) {
    if (!mounted) return;
    final notifier = ref.read(adsNotifierProvider.notifier);
    final current = ref.read(adsNotifierProvider);
    final wanted = widget.initialFilter;
    if (wanted != null && !sameSearch(wanted, current.filter)) {
      notifier.applyFilter(wanted);
    } else if (firstOpen && current.ads.isEmpty && !current.isLoading) {
      notifier.refresh();
    } else if (firstOpen) {
      _syncUrl(current.filter);
    }
  }

  static bool _sameQuery(Uri a, Uri b) {
    final x = a.queryParameters, y = b.queryParameters;
    return a.path == b.path && x.length == y.length && x.entries.every((e) => y[e.key] == e.value);
  }

  /// Keeps the address in step with the search without growing the history.
  void _syncUrl(AdsFilter filter) {
    if (!mounted) return;
    final target = exploreLocation(filter);
    if (GoRouter.maybeOf(context) == null) return;
    // This page's own address (also right when Explore was pushed on top of Home).
    final here = GoRouterState.of(context).uri;
    if (!_sameQuery(here, Uri.parse(target))) context.replace(target);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(adsNotifierProvider.notifier).load();
    }
  }

  // Keeps the other filters: a new query only replaces the text.
  void _search(String q) {
    final current = ref.read(adsNotifierProvider).filter;
    ref.read(adsNotifierProvider.notifier).applyFilter(current.withQuery(q.isNotEmpty ? q : null));
  }

  Future<void> _saveSearch() async {
    final messenger = ScaffoldMessenger.of(context);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('سجّل الدخول عشان تحفظ البحث وتوصلك التنبيهات')));
      return;
    }
    final filter = ref.read(adsNotifierProvider).filter;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _SaveSearchDialog(initialName: defaultSavedSearchName(filter)),
    );
    if (name == null || !mounted) return;
    final row = savedSearchRow(filter, userId: userId, name: name);
    if (row == null) return;
    try {
      await saveSearch(ref.read(savedRepositoryProvider), row);
      ref.invalidate(savedSearchesProvider);
      messenger.showSnackBar(const SnackBar(content: Text('تم حفظ البحث. هنبعتلك تنبيه أول ما ينزل إعلان مطابق.')));
    } on SavedSearchLimitReached catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر حفظ البحث. حاول مرة أخرى.')));
    }
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
    // Keep the search box in step when the query changes elsewhere (saved search, clear).
    ref.listen(adsNotifierProvider.select((s) => s.filter.query), (_, q) {
      if ((q ?? '') != _searchCtrl.text) _searchCtrl.text = q ?? '';
    });
    ref.listen(adsNotifierProvider.select((s) => s.filter), (prev, next) {
      if (prev == null || !sameSearch(prev, next)) _syncUrl(next);
    });

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
                  if (adsState.filter.hasCriteria)
                    TextButton.icon(
                      onPressed: _saveSearch,
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: const Text('احفظ البحث'),
                    ),
                  _ViewToggle(
                    view: _view,
                    onToggle: (v) => setState(() => _view = v),
                  ),
                ],
              ),
            ),

            // ── Results ──────────────────────────────────────
            Expanded(
              // The map (FR-2.4) shows every matching ad in view, not just the loaded page.
              child: _view == _ResultsView.map
                  ? const AdsMapView()
                  : adsState.isLoading && adsState.ads.isEmpty
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
                      : _view == _ResultsView.grid
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
enum _ResultsView { grid, list, map }

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onToggle});
  final _ResultsView view;
  final ValueChanged<_ResultsView> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _ToggleBtn(icon: Icons.grid_view_rounded, isActive: view == _ResultsView.grid, onTap: () => onToggle(_ResultsView.grid)),
          _ToggleBtn(icon: Icons.view_list_rounded, isActive: view == _ResultsView.list, onTap: () => onToggle(_ResultsView.list)),
          _ToggleBtn(icon: Icons.map_outlined,      isActive: view == _ResultsView.map,  onTap: () => onToggle(_ResultsView.map)),
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
  static const _maxPriceRange = 50000.0;
  // Posting-date choices, in days (null: any time).
  static const _dateOptions = <(String, int?)>[
    ('أي وقت', null),
    ('آخر 24 ساعة', 1),
    ('آخر أسبوع', 7),
    ('آخر شهر', 30),
  ];

  int? _governorateId;
  int? _cityId;
  int? _districtId;
  int? _postedWithinDays;
  String? _adType;
  double _minPrice = 0;
  double _maxPrice = _maxPriceRange;

  @override
  void initState() {
    super.initState();
    // Open on the filters already applied.
    final f = ref.read(adsNotifierProvider).filter;
    _cityId = f.cityId;
    _districtId = f.districtId;
    _postedWithinDays = f.postedWithinDays;
    _adType = f.adType;
    _minPrice = (f.minPrice ?? 0).clamp(0, _maxPriceRange).toDouble();
    _maxPrice = (f.maxPrice ?? _maxPriceRange).clamp(0, _maxPriceRange).toDouble();
    if (_cityId != null) {
      // The governorate of an already chosen city, so its dropdown shows it.
      ref.read(cityByIdProvider(_cityId!).future).then((city) {
        if (mounted && city != null) setState(() => _governorateId = city['governorate_id'] as int?);
      });
    }
  }

  List<DropdownMenuItem<int?>> _items(List<Map<String, dynamic>> rows, String anyLabel) => [
        DropdownMenuItem<int?>(value: null, child: Text(anyLabel)),
        for (final r in rows) DropdownMenuItem<int?>(value: r['id'] as int, child: Text(r['name_ar'] as String? ?? '')),
      ];

  Widget _dropdown({
    required String label,
    required int? value,
    required List<DropdownMenuItem<int?>> items,
    required ValueChanged<int?>? onChanged,
  }) {
    // Keep the value only when the list contains it (lists load asynchronously).
    final present = items.any((i) => i.value == value);
    return DropdownButtonFormField<int?>(
      key: ValueKey('$label:${present ? value : null}:${items.length}'),
      initialValue: present ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: items,
      onChanged: onChanged,
    );
  }

  void _apply() {
    final current = ref.read(adsNotifierProvider).filter;
    // Keeps the text query and category; everything in the sheet is replaced.
    ref.read(adsNotifierProvider.notifier).applyFilter(
          current.withRefinements(
            cityId: _cityId,
            districtId: _districtId,
            adType: _adType,
            minPrice: _minPrice > 0 ? _minPrice : null,
            maxPrice: _maxPrice < _maxPriceRange ? _maxPrice : null,
            postedWithinDays: _postedWithinDays,
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const none = <Map<String, dynamic>>[];
    final governorates = ref.watch(governoratesProvider).valueOrNull ?? none;
    final cities = _governorateId == null ? none : ref.watch(citiesProvider(_governorateId!)).valueOrNull ?? none;
    final districts = _cityId == null ? none : ref.watch(districtsProvider(_cityId!)).valueOrNull ?? none;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
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

            // Location: governorate -> city -> district
            Text('المكان', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            _dropdown(
              label: 'المحافظة',
              value: _governorateId,
              items: _items(governorates, 'كل المحافظات'),
              onChanged: (v) => setState(() {
                _governorateId = v;
                _cityId = null;
                _districtId = null;
              }),
            ),
            const SizedBox(height: 10),
            _dropdown(
              label: 'المدينة',
              value: _cityId,
              items: _items(cities, 'كل المدن'),
              onChanged: _governorateId == null
                  ? null
                  : (v) => setState(() {
                        _cityId = v;
                        _districtId = null;
                      }),
            ),
            const SizedBox(height: 10),
            _dropdown(
              label: 'الحي',
              value: _districtId,
              items: _items(districts, 'كل الأحياء'),
              onChanged: _cityId == null ? null : (v) => setState(() => _districtId = v),
            ),
            const SizedBox(height: 20),

            // Posting date
            Text('تاريخ النشر', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final (label, days) in _dateOptions)
                  _FilterChip(
                    label: label,
                    value: days?.toString(),
                    selected: _postedWithinDays == days,
                    onTap: () => setState(() => _postedWithinDays = days),
                  ),
              ],
            ),
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
              min: 0, max: _maxPriceRange,
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
                      ref.read(adsNotifierProvider.notifier).clearFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('مسح الكل'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    child: const Text('تطبيق'),
                  ),
                ),
              ],
            ),
          ],
        ),
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

class _SaveSearchDialog extends StatefulWidget {
  const _SaveSearchDialog({required this.initialName});
  final String initialName;

  @override
  State<_SaveSearchDialog> createState() => _SaveSearchDialogState();
}

class _SaveSearchDialogState extends State<_SaveSearchDialog> {
  late final _ctrl = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('احفظ البحث'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('هنبعتلك إشعار لما ينزل إعلان جديد يطابق البحث ده.'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLength: 100,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'اسم البحث'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: const Text('حفظ')),
      ],
    );
  }
}
