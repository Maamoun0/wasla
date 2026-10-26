import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/features/profile/providers/subscription_controller.dart';

void main() {
  group('monthlyPackageOf', () {
    test('returns the 30-day package attached to a plan', () {
      final plan = {
        'id': 3,
        'price_monthly': 199,
        'payment_packages': [
          {'id': 'sub_premium_yearly', 'price_egp': 1900, 'duration_days': 365},
          {'id': 'sub_premium_monthly', 'price_egp': 199, 'duration_days': 30},
        ],
      };
      expect(monthlyPackageOf(plan)?['id'], 'sub_premium_monthly');
    });

    test('returns null when the plan has no purchasable package (e.g. free plan)', () {
      expect(monthlyPackageOf({'id': 1, 'payment_packages': []}), isNull);
      expect(monthlyPackageOf({'id': 1}), isNull);
    });
  });
}
