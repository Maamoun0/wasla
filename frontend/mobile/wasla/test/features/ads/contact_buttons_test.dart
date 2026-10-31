import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/features/ads/screens/ad_detail_screen.dart';
import 'package:wasla/features/auth/providers/auth_provider.dart';
import 'package:wasla/shared/providers/ads_provider.dart';

void main() {
  group('sellerContactUri', () {
    test('a call dials the revealed number', () {
      expect(sellerContactUri('phone', '+20 101 234 5678', 'x').toString(), 'tel:+201012345678');
    });

    test('WhatsApp opens wa.me with a ready message naming the ad', () {
      final uri = sellerContactUri('whatsapp', '+201012345678', 'آيفون 13')!;
      expect([uri.host, uri.path], ['wa.me', '/201012345678']);
      expect(uri.queryParameters['text'], 'مرحباً، بخصوص إعلانك "آيفون 13" على وصلة');
    });

    test('no usable number, no link', () {
      expect(sellerContactUri('phone', '', 'x'), isNull);
      expect(sellerContactUri('sms', '+201012345678', 'x'), isNull);
    });
  });

  testWidgets('each contact button reveals the number through reveal_seller_phone (which logs contact_logs) and opens the app',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reveals = <(String, String)>[];
    final opened = <Uri>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => 'buyer-1'),
        supabaseClientProvider.overrideWith((ref) => SupabaseClient('http://localhost:1', 'k',
            authOptions: const AuthClientOptions(autoRefreshToken: false))),
        adDetailProvider.overrideWith((ref, id) async => {
              'id': id,
              'title': 'آيفون 13',
              'description': 'وصف',
              'price': 1000,
              'price_type': 'fixed',
              'user_id': 'seller-1',
              'ad_media': <dynamic>[],
              'users': {'full_name': 'بائع'},
              'cities': {'name_ar': 'القاهرة'},
            }),
        sellerPhoneRevealerProvider.overrideWith((ref) => (adId, type) async {
              reveals.add((adId, type));
              return const SellerPhoneRevealed('+201012345678');
            }),
        externalLinkLauncherProvider.overrideWith((ref) => (uri) async => opened.add(uri)),
      ],
      child: const MaterialApp(home: AdDetailScreen(adId: 'ad-1')),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('اتصال'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('واتساب'));
    await tester.pumpAndSettle();

    expect(reveals, [('ad-1', 'phone'), ('ad-1', 'whatsapp')]);
    expect(opened.map((u) => u.scheme), ['tel', 'https']);
    expect(opened.last.queryParameters['text'], contains('آيفون 13'));
  });
}
