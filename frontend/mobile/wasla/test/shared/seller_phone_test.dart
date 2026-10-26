import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/shared/providers/ads_provider.dart';

void main() {
  group('parseSellerPhoneResponse', () {
    test('ok with a phone is revealed', () {
      final r = parseSellerPhoneResponse({'status': 'ok', 'phone': '+201000000002'});
      expect(r, isA<SellerPhoneRevealed>());
      expect((r as SellerPhoneRevealed).phone, '+201000000002');
    });

    test('rate_limited carries the retry delay', () {
      final r = parseSellerPhoneResponse({'status': 'rate_limited', 'retry_after_seconds': 900});
      expect(r, isA<SellerPhoneRateLimited>());
      expect((r as SellerPhoneRateLimited).retryAfter, const Duration(minutes: 15));
    });

    test('not_available, empty phone or unexpected payloads are unavailable', () {
      expect(parseSellerPhoneResponse({'status': 'not_available'}), isA<SellerPhoneUnavailable>());
      expect(parseSellerPhoneResponse({'status': 'ok', 'phone': ''}), isA<SellerPhoneUnavailable>());
      expect(parseSellerPhoneResponse(null), isA<SellerPhoneUnavailable>());
    });
  });
}
