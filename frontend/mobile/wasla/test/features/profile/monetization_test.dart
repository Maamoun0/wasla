import 'package:flutter_test/flutter_test.dart';

// Model to represent a parsed boost package in test
class BoostPackage {
  final String key;
  final double price;
  final String nameAr;
  final String type;
  final int durationDays;

  BoostPackage({
    required this.key,
    required this.price,
    required this.nameAr,
    required this.type,
    required this.durationDays,
  });
}

// Logic mapper for boost packages (extracted from controller to make testable)
class BoostPackageParser {
  static List<BoostPackage> parse(List<Map<String, dynamic>> rawConfigs) {
    final List<BoostPackage> parsedPackages = [];
    
    for (final item in rawConfigs) {
      final key = item['key'] as String?;
      if (key == null || !key.startsWith('boost_')) continue;

      final value = double.tryParse(item['value'] as String? ?? '0') ?? 0.0;

      String nameAr = 'باقة الترقية';
      String type = 'bump';
      int durationDays = 1;

      if (key == 'boost_featured_3d') {
        nameAr = 'إعلان مميز (3 أيام)';
        type = 'featured';
        durationDays = 3;
      } else if (key == 'boost_featured_7d') {
        nameAr = 'إعلان مميز (7 أيام)';
        type = 'featured';
        durationDays = 7;
      } else if (key == 'boost_featured_14d') {
        nameAr = 'إعلان مميز (14 يوم)';
        type = 'featured';
        durationDays = 14;
      } else if (key == 'boost_featured_30d') {
        nameAr = 'إعلان مميز (30 يوم)';
        type = 'featured';
        durationDays = 30;
      } else if (key == 'boost_urgent_7d') {
        nameAr = 'إعلان عاجل (7 أيام)';
        type = 'urgent';
        durationDays = 7;
      } else if (key == 'boost_bump') {
        nameAr = 'تحديث الترتيب (Bump)';
        type = 'bump';
        durationDays = 1;
      } else {
        continue;
      }

      parsedPackages.add(BoostPackage(
        key: key,
        price: value,
        nameAr: nameAr,
        type: type,
        durationDays: durationDays,
      ));
    }

    parsedPackages.sort((a, b) => a.price.compareTo(b.price));
    return parsedPackages;
  }
}

// Subscription warning helper (extracted from controller to make testable)
class SubscriptionWarningHelper {
  static bool shouldShowWarning(Map<String, dynamic>? activeSubscription, Map<String, dynamic> selectedPlan) {
    if (activeSubscription == null) return false;

    final activePlanId = activeSubscription['plan_id'] as num?;
    // planId == 1 is the 'free' plan from schema seeds, which does not trigger warnings
    if (activePlanId == null || activePlanId == 1) return false;

    // Trigger warning if upgrading to a different plan
    return activePlanId != selectedPlan['id'];
  }
}

void main() {
group('Wasla Monetization Logic Unit Tests', () {
    test('Parse boost packages from raw DB configs', () {
      final List<Map<String, dynamic>> mockConfigs = [
        {'key': 'max_free_ads', 'value': '5'},
        {'key': 'boost_featured_7d', 'value': '60'},
        {'key': 'boost_urgent_7d', 'value': '40'},
        {'key': 'boost_bump', 'value': '10'},
      ];

      final packages = BoostPackageParser.parse(mockConfigs);

      expect(packages.length, 3);
      // Verify sorting order by price ascending (10, 40, 60)
      expect(packages[0].key, 'boost_bump');
      expect(packages[0].price, 10.0);
      expect(packages[0].type, 'bump');

      expect(packages[1].key, 'boost_urgent_7d');
      expect(packages[1].price, 40.0);
      expect(packages[1].type, 'urgent');

      expect(packages[2].key, 'boost_featured_7d');
      expect(packages[2].price, 60.0);
      expect(packages[2].type, 'featured');
    });

    test('Subscription warning displays correctly based on active plan status', () {
      final freeSubscription = {
        'plan_id': 1,
        'status': 'active',
      };
      
      final paidSubscription = {
        'plan_id': 3, // Premium plan
        'status': 'active',
      };

      final targetPlanBasic = {
        'id': 2,
        'name': 'basic',
      };

      final targetPlanPremium = {
        'id': 3,
        'name': 'premium',
      };

      // Case A: User has no active subscription -> No warning
      expect(SubscriptionWarningHelper.shouldShowWarning(null, targetPlanBasic), false);

      // Case B: User is on Free subscription -> No warning
      expect(SubscriptionWarningHelper.shouldShowWarning(freeSubscription, targetPlanBasic), false);

      // Case C: User is on Paid subscription and upgrading to different paid plan -> Warning shown
      expect(SubscriptionWarningHelper.shouldShowWarning(paidSubscription, targetPlanBasic), true);

      // Case D: User is on Paid subscription and selecting the exact same plan -> No warning
      expect(SubscriptionWarningHelper.shouldShowWarning(paidSubscription, targetPlanPremium), false);
    });
  });
}
