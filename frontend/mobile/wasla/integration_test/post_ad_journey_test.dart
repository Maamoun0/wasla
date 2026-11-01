// Posting an ad on a device, against a running local Supabase stack:
//
//   flutter test integration_test/post_ad_journey_test.dart -d <emulator>
//     --dart-define=SUPABASE_URL=http://10.0.2.2:54321
//     --dart-define=SUPABASE_ANON_KEY=<anon key from `supabase status`>
//
// Signs in with the local-only test number (supabase/config.toml), drives the
// real app from category to publish, and checks the ad reached the database
// as pending review. The camera and gallery are faked; everything else is real.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/core/router/app_router.dart';
import 'package:wasla/main.dart';

import '../test/helpers/fake_picker.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _testPhone = '+201000000101';
const _testCode = '123456';

Future<void> _settle(WidgetTester tester, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  do {
    await tester.pump(const Duration(milliseconds: 200));
  } while (tester.binding.hasScheduledFrame && DateTime.now().isBefore(end));
}

Future<void> _waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) throw TestFailure('timed out waiting for $finder');
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await _settle(tester);
}

/// Opens the dropdown whose hint is [hint] and chooses [item].
Future<void> _pick(WidgetTester tester, String hint, String item) async {
  await _tap(tester, find.ancestor(of: find.text(hint), matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField)));
  await _tap(tester, find.text(item).last);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a signed-in user posts an ad from category to publish', (tester) async {
    expect(_url, isNotEmpty, reason: 'pass --dart-define=SUPABASE_URL');
    FakeImagePicker.install();
    await EasyLocalization.ensureInitialized();
    await Supabase.initialize(url: _url, publishableKey: _anonKey);
    final client = Supabase.instance.client;

    // Sign in (test number: no SMS is sent) and accept the current legal versions
    // so the consent dialog does not cover the flow.
    await client.auth.signInWithOtp(phone: _testPhone);
    await client.auth.verifyOTP(phone: _testPhone, token: _testCode, type: OtpType.sms);
    final userId = client.auth.currentUser!.id;
    final legal = await client.from('app_configs').select('key, value').inFilter('key', ['legal_terms', 'legal_privacy']);
    final versions = {for (final r in legal) r['key']: (r['value'] as Map)['version']};
    await client.rpc('accept_legal_documents', params: {
      'p_terms_version': versions['legal_terms'],
      'p_privacy_version': versions['legal_privacy'],
    });

    // Leave the stack as it was: the test ads and their photos go, pass or fail
    // (owners may delete both).
    final title = 'شقة اختبار الجهاز ${DateTime.now().millisecondsSinceEpoch}';
    addTearDown(() async {
      final ads = await client.from('ads').select('id, ad_media(url)').eq('user_id', userId).eq('title', title);
      for (final ad in ads) {
        final paths = [
          for (final m in ad['ad_media'] as List) (m['url'] as String).split('/object/public/ads/').last,
        ];
        if (paths.isNotEmpty) await client.storage.from('ads').remove(paths);
        await client.from('ads').delete().eq('id', ad['id']);
      }
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
        path: 'assets/translations',
        fallbackLocale: const Locale('ar', 'EG'),
        startLocale: const Locale('ar', 'EG'),
        child: const WaslaApp(),
      ),
    ));
    await _settle(tester);
    container.read(routerProvider).go(AppRoutes.postCategory);
    await _settle(tester);

    // Category: real estate, then flats for sale.
    await _tap(tester, find.text('عقارات'));
    await _tap(tester, find.text('شقق للبيع'));

    // Details, with the category's required fields.
    await _waitFor(tester, find.text('القسم المختار: شقق للبيع'));
    await tester.enterText(find.byType(TextFormField).at(0), title);
    await tester.enterText(find.byType(TextFormField).at(1), 'شقة للاختبار على المحاكي، 120 متر، الدور الخامس.');
    await tester.enterText(find.byType(TextFormField).at(2), '120');
    await _settle(tester);
    await _pick(tester, 'اختر عدد الغرف', '3');
    await _pick(tester, 'اختر التشطيب', 'سوبر لوكس');
    await _tap(tester, find.text('التالي'));

    // Photos: two from the (fake) gallery, uploaded to local Storage.
    await _tap(tester, find.text('إضافة صورة'));
    await _tap(tester, find.text('المعرض (Gallery)'));
    await _waitFor(tester, find.text('تم الرفع بنجاح'));
    await _tap(tester, find.text('التالي'));

    // Location and price.
    await _pick(tester, 'اختر المحافظة', 'القاهرة');
    await _pick(tester, 'اختر المدينة', 'الزمالك');
    await tester.enterText(find.widgetWithText(TextFormField, 'ادخل السعر بالجنيه'), '3500000');
    await _settle(tester);
    await _tap(tester, find.text('التالي'));

    // Preview, then publish through create-ad.
    await _waitFor(tester, find.text(title));
    await _tap(tester, find.text('انشر الإعلان الآن'));
    await _waitFor(tester, find.text('تم نشر إعلانك بنجاح!'), timeout: const Duration(seconds: 60));

    final ad = await client
        .from('ads')
        .select('id, status, title, city_id, price, ad_media(url, is_primary)')
        .eq('user_id', userId)
        .eq('title', title)
        .single();
    expect(ad['status'], 'pending');
    expect(ad['price'], 3500000);
    expect((ad['ad_media'] as List).length, 2);
  });
}
