import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../providers/post_ad_wizard_provider.dart';
import '../../../shared/providers/locations_provider.dart';
import '../models/draft_ad.dart';

class LocationPriceScreen extends ConsumerStatefulWidget {
  const LocationPriceScreen({super.key});

  @override
  ConsumerState<LocationPriceScreen> createState() => _LocationPriceScreenState();
}

class _LocationPriceScreenState extends ConsumerState<LocationPriceScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _priceController;
  
  int? _selectedGovId;
  int? _selectedCityId;
  int? _selectedDistrictId;
  
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(postAdWizardProvider).draft;
    _priceController = TextEditingController(
      text: draft.price != null ? draft.price!.toInt().toString() : '',
    );
    _selectedCityId = draft.cityId;
    _selectedDistrictId = draft.districtId;
    _latitude = draft.latitude;
    _longitude = draft.longitude;
  }

  @override
  void dispose() {
    _priceController.dispose();
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

  Future<void> _openMapPicker() async {
    final LatLng? result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (ctx) => MapPickerScreen(
          initialLocation: _latitude != null && _longitude != null
              ? LatLng(_latitude!, _longitude!)
              : const LatLng(30.0444, 31.2357), // Default to Cairo
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
      _saveLocationToProvider();
    }
  }

  void _saveLocationToProvider() {
    if (_selectedCityId != null) {
      ref.read(postAdWizardProvider.notifier).setLocation(
        cityId: _selectedCityId!,
        districtId: _selectedDistrictId,
        latitude: _latitude,
        longitude: _longitude,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postAdWizardProvider);
    final notifier = ref.read(postAdWizardProvider.notifier);
    final draft = state.draft;

    final govsAsync = ref.watch(governoratesProvider);
    final citiesAsync = _selectedGovId != null ? ref.watch(citiesProvider(_selectedGovId!)) : null;
    final districtsAsync = _selectedCityId != null ? ref.watch(districtsProvider(_selectedCityId!)) : null;

    final isValid = notifier.isStepValid(WizardStep.location);

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
          title: const Text('الموقع والسعر'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: 4 / 5,
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
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── SECTION 1: LOCATION ──
                        const Text(
                          'الموقع الجغرافي',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary700,
                          ),
                        ),
                        const SizedBox(height: AppSizes.md),

                        // Governorate Dropdown
                        govsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('خطأ في تحميل المحافظات: $e', style: const TextStyle(fontFamily: 'Cairo')),
                          data: (govs) {
                            return DropdownButtonFormField<int>(
                              // Keyed so the field resets when the selection changes elsewhere.
                              key: ValueKey(_selectedGovId),
                              initialValue: _selectedGovId,
                              hint: const Text('اختر المحافظة', style: TextStyle(fontFamily: 'Cairo')),
                              decoration: const InputDecoration(
                                labelText: 'المحافظة',
                                prefixIcon: Icon(Icons.map_rounded, color: AppColors.neutral500),
                              ),
                              items: govs.map((g) {
                                return DropdownMenuItem<int>(
                                  value: g['id'] as int,
                                  child: Text(g['name_ar'] as String, style: const TextStyle(fontFamily: 'Cairo')),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedGovId = val;
                                  _selectedCityId = null;
                                  _selectedDistrictId = null;
                                });
                              },
                              validator: (val) => val == null ? 'يرجى اختيار المحافظة' : null,
                            );
                          },
                        ),
                        const SizedBox(height: AppSizes.md),

                        // City Dropdown
                        if (_selectedGovId != null && citiesAsync != null)
                          citiesAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('خطأ في تحميل المدن: $e', style: const TextStyle(fontFamily: 'Cairo')),
                            data: (cities) {
                              if (cities.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(AppSizes.sm),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, color: AppColors.error, size: 20),
                                      SizedBox(width: AppSizes.sm),
                                      Expanded(
                                        child: Text(
                                          'عفواً، لا توجد مدن متاحة لهذه المحافظة حالياً في قاعدة البيانات. يرجى اختيار محافظة أخرى.',
                                          style: TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return DropdownButtonFormField<int>(
                                // Keyed so the field resets when the selection changes elsewhere.
                                key: ValueKey(_selectedCityId),
                                initialValue: _selectedCityId,
                                hint: const Text('اختر المدينة', style: TextStyle(fontFamily: 'Cairo')),
                                decoration: const InputDecoration(
                                  labelText: 'المدينة / المنطقة',
                                  prefixIcon: Icon(Icons.location_city_rounded, color: AppColors.neutral500),
                                ),
                                items: cities.map((c) {
                                  return DropdownMenuItem<int>(
                                    value: c['id'] as int,
                                    child: Text(c['name_ar'] as String, style: const TextStyle(fontFamily: 'Cairo')),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  final city = cities.firstWhere((c) => c['id'] == val);
                                  setState(() {
                                    _selectedCityId = val;
                                    _selectedDistrictId = null;
                                  });
                                  notifier.setLocation(
                                    cityId: val!,
                                    cityNameAr: city['name_ar'] as String,
                                  );
                                },
                                validator: (val) => val == null ? 'يرجى اختيار المدينة' : null,
                              );
                            },
                          ),
                        const SizedBox(height: AppSizes.md),

                        // District Dropdown (Cascading / Conditional)
                        if (_selectedCityId != null && districtsAsync != null)
                          districtsAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (e, _) => const SizedBox.shrink(),
                            data: (districts) {
                              if (districts.isEmpty) {
                                return const SizedBox.shrink(); // Hide completely if city has no districts
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSizes.md),
                                child: DropdownButtonFormField<int>(
                                  // Keyed so the field resets when the selection changes elsewhere.
                                  key: ValueKey(_selectedDistrictId),
                                  initialValue: _selectedDistrictId,
                                  hint: const Text('اختر الحي (اختياري)', style: TextStyle(fontFamily: 'Cairo')),
                                  decoration: const InputDecoration(
                                    labelText: 'الحي التفصيلي',
                                    prefixIcon: Icon(Icons.holiday_village_rounded, color: AppColors.neutral500),
                                  ),
                                  items: districts.map((d) {
                                    return DropdownMenuItem<int>(
                                      value: d['id'] as int,
                                      child: Text(d['name_ar'] as String, style: const TextStyle(fontFamily: 'Cairo')),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    final dist = districts.firstWhere((d) => d['id'] == val);
                                    setState(() {
                                      _selectedDistrictId = val;
                                    });
                                    notifier.setLocation(
                                      cityId: _selectedCityId!,
                                      districtId: val,
                                      districtNameAr: dist['name_ar'] as String,
                                      latitude: _latitude,
                                      longitude: _longitude,
                                    );
                                  },
                                ),
                              );
                            },
                          ),

                        // Precise map location picker (optional; needs a Maps key)
                        if (AppConfig.mapsEnabled)
                        OutlinedButton.icon(
                          onPressed: _openMapPicker,
                          icon: const Icon(Icons.my_location_rounded, size: 18),
                          label: Text(
                            _latitude != null && _longitude != null
                                ? 'تم تحديد الموقع على الخريطة بنجاح'
                                : 'تحديد موقع دقيق على الخريطة (اختياري)',
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _latitude != null && _longitude != null
                                ? Colors.green
                                : AppColors.primary600,
                            side: BorderSide(
                              color: _latitude != null && _longitude != null
                                  ? Colors.green
                                  : AppColors.primary600,
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSizes.lg),
                        const Divider(color: AppColors.neutral200),
                        const SizedBox(height: AppSizes.lg),

                        // ── SECTION 2: PRICE ──
                        const Text(
                          'السعر ونوع المعاملة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary700,
                          ),
                        ),
                        const SizedBox(height: AppSizes.md),

                        // Price type selector chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPriceTypeChip(PriceType.fixed, 'سعر ثابت'),
                            _buildPriceTypeChip(PriceType.negotiable, 'قابل للتفاوض'),
                            _buildPriceTypeChip(PriceType.free, 'مجانًا'),
                            _buildPriceTypeChip(PriceType.perHour, 'سعر بالساعة'),
                            _buildPriceTypeChip(PriceType.perMonth, 'سعر بالشهر'),
                          ],
                        ),
                        const SizedBox(height: AppSizes.lg),

                        // Price Input Field (Hidden if type is free)
                        if (draft.priceType != PriceType.free) ...[
                          const Text(
                            'المبلغ المطلوب (جنيه مصري)',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral800,
                            ),
                          ),
                          const SizedBox(height: AppSizes.sm),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              hintText: 'ادخل السعر بالجنيه',
                              suffixText: 'ج.م',
                              prefixIcon: Icon(Icons.payments_rounded, color: AppColors.neutral500),
                            ),
                            onChanged: (val) {
                              final p = double.tryParse(val);
                              notifier.setPrice(p);
                              setState(() {});
                            },
                            validator: (val) {
                              if (draft.priceType == PriceType.free) return null;
                              if (val == null || val.trim().isEmpty) return 'يرجى إدخال السعر';
                              final p = double.tryParse(val);
                              if (p == null || p <= 0) return 'يجب أن يكون السعر أكبر من الصفر';
                              if (p >= 100000000) return 'يجب أن يكون السعر أقل من 100,000,000 ج.م';
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
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
                        onPressed: () {
                          notifier.setStep(WizardStep.photos);
                          context.pop();
                        },
                        child: const Text('السابق', style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isValid && (_formKey.currentState?.validate() ?? false)
                            ? () {
                                _saveLocationToProvider();
                                notifier.setStep(WizardStep.preview);
                                context.push(AppRoutes.postPreview);
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

  Widget _buildPriceTypeChip(PriceType type, String label) {
    final isSelected = ref.watch(postAdWizardProvider).draft.priceType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: TextStyle(
        fontFamily: 'Cairo',
        color: isSelected ? Colors.white : AppColors.neutral700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selectedColor: AppColors.primary600,
      backgroundColor: AppColors.neutral100,
      onSelected: (selected) {
        if (selected) {
          ref.read(postAdWizardProvider.notifier).setPriceType(type);
          if (type == PriceType.free) {
            _priceController.clear();
          }
          setState(() {});
        }
      },
    );
  }
}

// ── MAP PICKER SCREEN ──
class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  const MapPickerScreen({super.key, required this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _selectedLatLng;

  @override
  void initState() {
    super.initState();
    _selectedLatLng = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد موقع الإعلان الدقيق', style: TextStyle(fontFamily: 'Cairo')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation,
              zoom: 14.0,
            ),
            onTap: (LatLng loc) {
              setState(() {
                _selectedLatLng = loc;
              });
            },
            markers: _selectedLatLng != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected_loc'),
                      position: _selectedLatLng!,
                      infoWindow: const InfoWindow(title: 'الموقع المحدد'),
                    )
                  }
                : {},
          ),
          Positioned(
            bottom: AppSizes.lg,
            left: AppSizes.lg,
            right: AppSizes.lg,
            child: ElevatedButton(
              onPressed: _selectedLatLng != null
                  ? () => Navigator.of(context).pop(_selectedLatLng)
                  : null,
              child: const Text('تأكيد الموقع المختار', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
