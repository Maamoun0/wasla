import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wasla/core/router/app_router.dart';
import 'package:wasla/features/post_ad/screens/ad_form_screen.dart';
import 'package:wasla/features/post_ad/screens/ad_preview_screen.dart';
import 'package:wasla/features/post_ad/screens/add_photos_screen.dart';
import 'package:wasla/features/post_ad/screens/location_price_screen.dart';
import 'package:wasla/features/post_ad/screens/select_category_screen.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/fake_picker.dart';

final _postRoutes = <RouteBase>[
  GoRoute(path: AppRoutes.postCategory, builder: (_, __) => const SelectCategoryScreen()),
  GoRoute(path: AppRoutes.postForm, builder: (_, __) => const AdFormScreen()),
  GoRoute(path: AppRoutes.postPhotos, builder: (_, __) => const AddPhotosScreen()),
  GoRoute(path: AppRoutes.postLocation, builder: (_, __) => const LocationPriceScreen()),
  GoRoute(path: AppRoutes.postPreview, builder: (_, __) => const AdPreviewScreen()),
];

FakeBackend _backend({int liveAds = 0}) => FakeBackend({
      '/rest/v1/categories': (req) => req.url.queryParameters.containsKey('parent_id')
          ? [
              {'id': 11, 'name_ar': 'شقق للبيع', 'icon': '🏢', 'parent_id': 1},
            ]
          : [
              {'id': 1, 'name_ar': 'عقارات', 'icon': '🏠', 'level': 1},
              {'id': 2, 'name_ar': 'سيارات', 'icon': '🚗', 'level': 1},
            ],
      '/rest/v1/rpc/my_plan_usage': (_) =>
          {'plan': 'free', 'plan_name_ar': 'مجانية', 'max_ads': 5, 'max_images_per_ad': 8, 'live_ads': liveAds},
      '/rest/v1/rpc/get_category_fields': (_) => [
            {'id': 101, 'field_name': 'rooms', 'label_ar': 'عدد الغرف', 'field_type': 'number', 'is_required': true},
            {'id': 102, 'field_name': 'finish', 'label_ar': 'التشطيب', 'field_type': 'select', 'options': ['سوبر لوكس', 'نص تشطيب']},
            {'id': 103, 'field_name': 'elevator', 'label_ar': 'أسانسير', 'field_type': 'boolean'},
          ],
      '/storage/v1/object/ads/*': (req) => {'Key': 'ads/${req.url.pathSegments.skip(4).join('/')}'},
      '/rest/v1/governorates': (_) => [
            {'id': 1, 'name_ar': 'القاهرة'}
          ],
      '/rest/v1/cities': (_) => [
            {'id': 5, 'name_ar': 'مدينة نصر', 'governorate_id': 1}
          ],
      '/rest/v1/districts': (_) => [
            {'id': 50, 'name_ar': 'الحي السابع', 'city_id': 5}
          ],
      '/rest/v1/rpc/get_my_profile': (_) => {'id': 'u1', 'full_name': 'سارة', 'trust_score': 70},
      '/functions/v1/create-ad': (_) => {'ad_id': 'new-ad-1', 'status': 'pending'},
    });

Future<void> _choose(WidgetTester tester, String label, String item) async {
  await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(FakeImagePicker.install);

  testWidgets('posts an ad end to end: category, details, photos, location and price, preview, publish', (tester) async {
    final backend = _backend();
    final nav = NavProbe();
    await pumpRoutes(tester, _postRoutes, initialLocation: AppRoutes.postCategory, backend: backend, nav: nav);

    // 1. Category, then subcategory.
    await tester.tap(find.text('عقارات'));
    await tester.pumpAndSettle();
    expect(find.text('اختر القسم الفرعي'), findsOneWidget);
    await tester.tap(find.text('شقق للبيع'));
    await tester.pumpAndSettle();

    // 2. Details and the category's own fields.
    expect(find.text('القسم المختار: شقق للبيع'), findsOneWidget);
    expect(backend.lastBody('/rest/v1/rpc/get_category_fields'), {'p_category_id': 11});
    await tester.enterText(find.byType(TextFormField).at(0), 'شقة للبيع في مدينة نصر');
    await tester.enterText(find.byType(TextFormField).at(1), 'شقة 120 متر، الدور الخامس، قريبة من الخدمات.');
    await tester.enterText(find.byType(TextFormField).at(2), '3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    // 3. Photos from the gallery, uploaded into the user's own folder.
    expect(find.text('لا توجد صور بعد'), findsOneWidget);
    await tester.tap(find.text('إضافة صورة'));
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.text('المعرض (Gallery)'));
    expect(find.text('الصور المضافة (2/8)'), findsOneWidget);
    expect(find.text('صورة الغلاف'), findsOneWidget);
    final uploads = backend.requests.where((r) => r.url.path.startsWith('/storage/v1/object/ads/')).toList();
    expect(uploads, hasLength(2));
    expect(uploads.every((r) => r.url.path.startsWith('/storage/v1/object/ads/u1/')), isTrue);
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    // 4. Location and price.
    await _choose(tester, 'المحافظة', 'القاهرة');
    await _choose(tester, 'المدينة / المنطقة', 'مدينة نصر');
    await _choose(tester, 'الحي التفصيلي', 'الحي السابع');
    await tester.enterText(find.widgetWithText(TextFormField, 'ادخل السعر بالجنيه'), '2500000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    // 5. Preview shows what will be published.
    expect(find.text('معاينة الإعلان'), findsOneWidget);
    expect(find.text('شقة للبيع في مدينة نصر'), findsOneWidget);
    expect(find.textContaining('مدينة نصر'), findsWidgets);
    await tapAndWait(tester, find.text('انشر الإعلان الآن'));

    final body = backend.lastBody('/functions/v1/create-ad') as Map<String, dynamic>;
    expect(body['category_id'], 11);
    expect(body['title'], 'شقة للبيع في مدينة نصر');
    expect(body['city_id'], 5);
    expect(body['district_id'], 50);
    expect(body['price'], 2500000);
    expect(body['price_type'], 'fixed');
    expect((body['images'] as List).length, 2);
    expect((body['images'] as List).first['is_primary'], isTrue);
    expect(jsonEncode(body['dynamic_fields']), contains('3'));
    expect(nav.location, '${AppRoutes.postSuccess}?id=new-ad-1');
    // Let the image cache's timers finish.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('at the plan limit, choosing a category explains it instead of opening the form', (tester) async {
    final nav = NavProbe();
    await pumpRoutes(tester, _postRoutes, initialLocation: AppRoutes.postCategory, backend: _backend(liveAds: 5), nav: nav);

    await tester.tap(find.text('عقارات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شقق للبيع'));
    await tester.pumpAndSettle();

    expect(find.textContaining('وصلت للحد الأقصى لباقة "مجانية"'), findsOneWidget);
    expect(find.text('القسم المختار: شقق للبيع'), findsNothing);
  });

  testWidgets('the details step validates title and description', (tester) async {
    await pumpRoutes(tester, _postRoutes, initialLocation: AppRoutes.postCategory, backend: _backend());
    await tester.tap(find.text('عقارات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شقق للبيع'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'قصير');
    await tester.enterText(find.byType(TextFormField).at(1), 'قصير كمان');
    await tester.pumpAndSettle();
    expect(find.text('يجب ألا يقل العنوان عن 10 أحرف'), findsOneWidget);
    expect(find.text('يجب ألا يقل الوصف عن 20 حرفاً'), findsOneWidget);
  });
}
